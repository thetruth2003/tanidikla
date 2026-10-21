param(
    [string]$BaseUrl = 'http://127.0.0.1:8080',
    [Parameter(Mandatory = $true)][string]$Email,
    [Parameter(Mandatory = $true)][string]$Password,
    [string]$CategoryId = 'electrician',
    [switch]$RunBurst
)

$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$csrfResponse = Invoke-RestMethod -WebSession $session -Method Get -Uri "$BaseUrl/api/v1/auth/csrf"
$csrf = [string]$csrfResponse.data.csrf_token

function JsonText($value) { $value | ConvertTo-Json -Depth 8 -Compress }
function ListingPayload([string]$suffix) {
    @{
        listing_type = 'service_offer'
        location = @{
            latitude = 39.9334
            longitude = 32.8597
            city = 'Ankara'
            district = 'Çankaya'
            neighborhood = 'Kızılay'
            precision = 'neighborhood'
        }
        items = @(@{
            category_id = $CategoryId
            title = "Spam güvenlik testi $suffix"
            description = "Yalnızca ayrı test ortamında idempotency ve moderasyon kontrolü için oluşturulan ilan $suffix."
            pricing_unit = 'negotiable'
            price_amount = $null
            price_includes_vat = $false
            urgent = $false
            open_24_7 = $false
            schedule_label = ''
        })
    }
}
function ApiErrorStatus($errorRecord) {
    if ($null -eq $errorRecord.Exception.Response) { return 0 }
    return [int]$errorRecord.Exception.Response.StatusCode
}

Invoke-RestMethod -WebSession $session -Method Post -Uri "$BaseUrl/api/v1/auth/login" `
    -Headers @{'X-CSRF-Token' = $csrf} -ContentType 'application/json; charset=utf-8' `
    -Body ([System.Text.Encoding]::UTF8.GetBytes((JsonText @{email = $Email; password = $Password}))) | Out-Null

$authCsrf = ($session.Cookies.GetCookies($BaseUrl) | Where-Object Name -eq 'ankara_csrf' | Select-Object -First 1).Value
$payload = ListingPayload "$stamp"
$idempotencyKey = "moderation-live-$stamp-primary"
$headers = @{'X-CSRF-Token' = $authCsrf; 'Idempotency-Key' = $idempotencyKey}
$created = Invoke-RestMethod -WebSession $session -Method Post -Uri "$BaseUrl/api/v1/listings" `
    -Headers $headers -ContentType 'application/json; charset=utf-8' `
    -Body ([System.Text.Encoding]::UTF8.GetBytes((JsonText $payload)))
if ($created.data.status -ne 'pending') { throw 'Yeni ilan onay bekliyor durumunda değil.' }

$replayed = Invoke-RestMethod -WebSession $session -Method Post -Uri "$BaseUrl/api/v1/listings" `
    -Headers $headers -ContentType 'application/json; charset=utf-8' `
    -Body ([System.Text.Encoding]::UTF8.GetBytes((JsonText $payload)))
if ($replayed.data.id -ne $created.data.id) { throw 'Aynı istek anahtarı ikinci ilan oluşturdu.' }

try {
    Invoke-RestMethod -WebSession $session -Method Post -Uri "$BaseUrl/api/v1/listings" `
        -Headers @{'X-CSRF-Token' = $authCsrf; 'Idempotency-Key' = "moderation-live-$stamp-duplicate"} `
        -ContentType 'application/json; charset=utf-8' `
        -Body ([System.Text.Encoding]::UTF8.GetBytes((JsonText $payload))) | Out-Null
    throw 'Aynı içerik yeni istek anahtarıyla kabul edildi.'
}
catch {
    if ((ApiErrorStatus $_) -ne 409) { throw }
}

try {
    Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/listings/$($created.data.id)" | Out-Null
    throw 'Onay bekleyen ilan herkese açık API üzerinden göründü.'
}
catch {
    if ((ApiErrorStatus $_) -ne 404) { throw }
}

$ownerListings = Invoke-RestMethod -WebSession $session -Method Get -Uri "$BaseUrl/api/v1/me/listings"
if ($created.data.id -notin @($ownerListings.data.items.id)) { throw 'Onay bekleyen ilan sahibinin listesinde görünmedi.' }

$burstResult = 'atlanmış'
if ($RunBurst) {
    $rateLimited = $false
    foreach ($index in 1..30) {
        $burstPayload = ListingPayload "$stamp-burst-$index"
        try {
            Invoke-RestMethod -WebSession $session -Method Post -Uri "$BaseUrl/api/v1/listings" `
                -Headers @{'X-CSRF-Token' = $authCsrf; 'Idempotency-Key' = "moderation-live-$stamp-burst-$index"} `
                -ContentType 'application/json; charset=utf-8' `
                -Body ([System.Text.Encoding]::UTF8.GetBytes((JsonText $burstPayload))) | Out-Null
        }
        catch {
            if ((ApiErrorStatus $_) -eq 429) { $rateLimited = $true; break }
            throw
        }
    }
    if (-not $rateLimited) { throw 'Kısa süreli otomatik ilan yağmuru 429 ile engellenmedi.' }
    $burstResult = '429-rate-limit-ok'
}

[pscustomobject]@{
    listing_id = $created.data.id
    moderation = 'pending-hidden-owner-visible'
    idempotency = 'same-id'
    duplicate = '409-blocked'
    burst = $burstResult
} | ConvertTo-Json -Compress

