param([string]$BaseUrl = 'http://127.0.0.1:8080')

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$settings = @{}
Get-Content (Join-Path $projectRoot '.env') -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^([A-Z0-9_]+)=(.*)$') { $settings[$matches[1]] = $matches[2].Trim('"') }
}
$psql = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $psql) { throw 'psql bulunamadi.' }
$env:PGPASSWORD = $settings.DB_PASSWORD
$stamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$password = 'AuditPass!2026'
$turkishName = [string]::Concat('G', [char]0x00FC, 'ven ', [char]0x015E, 'ahin')
$turkishBio = [string]::Concat('T', [char]0x00FC, 'rk', [char]0x00E7, 'e a', [char]0x00E7, [char]0x0131, 'klama: ', [char]0x011F, [char]0x00FC, [char]0x015F, [char]0x00F6, [char]0x00E7, [char]0x0131)
$adminId = $null; $ownerId = $null; $requesterId = $null; $conversationId = $null

function CookieValue($session, $name) {
    ($session.Cookies.GetCookies($BaseUrl) | Where-Object Name -eq $name | Select-Object -First 1).Value
}
function JsonText($value) { $value | ConvertTo-Json -Depth 8 -Compress }
function RegisterUser($email, $name) {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    Invoke-WebRequest -UseBasicParsing -WebSession $session "$BaseUrl/kayit" | Out-Null
    $preCsrf = CookieValue $session 'ankara_pre_auth_csrf'
    $result = Invoke-RestMethod -WebSession $session -Method Post -Uri "$BaseUrl/api/v1/auth/register" `
        -Headers @{'X-CSRF-Token' = $preCsrf} -ContentType 'application/json' `
        -Body (JsonText @{email = $email; password = $password; password_confirmation = $password; display_name = $name; message_email_notifications = $false})
    @{Session = $session; Id = $result.data.user.id; Csrf = (CookieValue $session 'ankara_csrf')}
}
function Psql($sql) {
    & $psql -h $settings.DB_HOST -p $settings.DB_PORT -U $settings.DB_USER -d $settings.DB_NAME -v ON_ERROR_STOP=1 -q -c $sql
    if ($LASTEXITCODE -ne 0) { throw 'Veritabani smoke islemi basarisiz.' }
}
function ExpectStatus([int]$Expected, [scriptblock]$Action, [string]$Label) {
    try {
        & $Action | Out-Null
    }
    catch {
        $actual = [int]$_.Exception.Response.StatusCode
        if ($actual -eq $Expected) { return }
        throw "$Label beklenen HTTP $Expected yerine HTTP $actual dondurdu."
    }
    throw "$Label HTTP $Expected ile engellenmedi."
}

try {
    $health = Invoke-RestMethod "$BaseUrl/api/v1/health"
    if ($health.data.database -ne 'ready') { throw 'Veritabani hazir degil.' }
    $admin = RegisterUser "smoke-admin-$stamp@example.test" 'Smoke Admin'; $adminId = $admin.Id
    $owner = RegisterUser "smoke-owner-$stamp@example.test" 'Smoke Owner'; $ownerId = $owner.Id
    $requester = RegisterUser "smoke-requester-$stamp@example.test" 'Smoke Requester'; $requesterId = $requester.Id
    Psql "update users set role='super_admin' where id='$adminId';" | Out-Null

    ExpectStatus 404 {
        Invoke-RestMethod -WebSession $owner.Session -Method Post -Uri "$BaseUrl/api/v1/profiles/$requesterId/phone-reveal" `
            -Headers @{'X-CSRF-Token' = $owner.Csrf} -ContentType 'application/json' -Body '{}'
    } 'Varsayilan telefon gizliligi'
    ExpectStatus 401 {
        Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/admin/stats"
    } 'Admin oturum ayrimi'

    try {
        Invoke-RestMethod -WebSession $owner.Session -Method Put -Uri "$BaseUrl/api/v1/profile" `
            -Headers @{'X-CSRF-Token' = $owner.Csrf} -ContentType 'application/json; charset=utf-8' `
            -Body ([System.Text.Encoding]::UTF8.GetBytes((JsonText @{
                display_name = $turkishName; bio = $turkishBio; city = 'Ankara'; district = 'Akyurt';
                phone_e164 = '05321234567'; phone_visible = $false; profile_type = 'business';
                business_name = 'Smoke Teknik 24'; business_address = 'Ataturk Bulvari No 10';
                business_services = $turkishBio; receive_category_ids = @('home_technical');
                provide_category_ids = @('computer_it')
            }))) | Out-Null
    } catch {
        throw "Profil guncelleme smoke testi basarisiz: $($_.ErrorDetails.Message)"
    }
    $ownerProfile = Invoke-RestMethod -WebSession $owner.Session -Uri "$BaseUrl/api/v1/profile"
    if ($ownerProfile.data.display_name -ne $turkishName -or $ownerProfile.data.bio -ne $turkishBio `
        -or $ownerProfile.data.profile_type -ne 'business' `
        -or 'home_technical' -notin @($ownerProfile.data.category_preferences.receive)) {
        throw 'Turkce profil, isletme turu veya kategori tercihleri korunmadi.'
    }
    Psql "update profiles set phone_verified_at=now(),phone_visible=true where user_id='$ownerId';" | Out-Null

    $submissionKey = "live-smoke-$stamp-listing"
    $listing = Invoke-RestMethod -WebSession $owner.Session -Method Post -Uri "$BaseUrl/api/v1/listings" `
        -Headers @{'X-CSRF-Token' = $owner.Csrf; 'Idempotency-Key' = $submissionKey} -ContentType 'application/json' -Body (JsonText @{
            listing_type = 'service_offer';
            location = @{latitude = 39.9334; longitude = 32.8597; city = 'Ankara'; district = 'Akyurt'; neighborhood = 'Merkez'; precision = 'neighborhood'};
            items = @(@{category_id = 'electrician'; title = 'Live smoke listing'; description = 'Temporary <script>alert("xss")</script> listing for repeatable validation.'; pricing_unit = 'negotiable'; price_amount = $null; price_includes_vat = $false; urgent = $true; open_24_7 = $true; schedule_label = 'Weekdays'})
        })
    if ($listing.data.status -ne 'pending') { throw 'Yeni ilan onay bekliyor durumunda olusmadi.' }
    $idempotentReplay = Invoke-RestMethod -WebSession $owner.Session -Method Post -Uri "$BaseUrl/api/v1/listings" `
        -Headers @{'X-CSRF-Token' = $owner.Csrf; 'Idempotency-Key' = $submissionKey} -ContentType 'application/json' -Body (JsonText @{
            listing_type = 'service_offer';
            location = @{latitude = 39.9334; longitude = 32.8597; city = 'Ankara'; district = 'Akyurt'; neighborhood = 'Merkez'; precision = 'neighborhood'};
            items = @(@{category_id = 'electrician'; title = 'Live smoke listing'; description = 'Temporary <script>alert("xss")</script> listing for repeatable validation.'; pricing_unit = 'negotiable'; price_amount = $null; price_includes_vat = $false; urgent = $true; open_24_7 = $true; schedule_label = 'Weekdays'})
        })
    if ($idempotentReplay.data.id -ne $listing.data.id) { throw 'Ayni istek anahtari ikinci ilan olusturdu.' }
    ExpectStatus 409 {
        Invoke-RestMethod -WebSession $owner.Session -Method Post -Uri "$BaseUrl/api/v1/listings" `
            -Headers @{'X-CSRF-Token' = $owner.Csrf; 'Idempotency-Key' = "live-smoke-$stamp-duplicate"} -ContentType 'application/json' -Body (JsonText @{
                listing_type = 'service_offer';
                location = @{latitude = 39.9334; longitude = 32.8597; city = 'Ankara'; district = 'Akyurt'; neighborhood = 'Merkez'; precision = 'neighborhood'};
                items = @(@{category_id = 'electrician'; title = 'Live smoke listing'; description = 'Temporary <script>alert("xss")</script> listing for repeatable validation.'; pricing_unit = 'negotiable'; price_amount = $null; price_includes_vat = $false; urgent = $true; open_24_7 = $true; schedule_label = 'Weekdays'})
            })
    } 'Ayni ilan korumasi'
    ExpectStatus 404 {
        Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/listings/$($listing.data.id)"
    } 'Onay bekleyen ilanin gizliligi'
    $ownerListings = Invoke-RestMethod -WebSession $owner.Session -Uri "$BaseUrl/api/v1/me/listings"
    if ($listing.data.id -notin @($ownerListings.data.items.id)) { throw 'Onay bekleyen ilan sahibine gosterilmedi.' }

    $adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    Invoke-WebRequest -UseBasicParsing -WebSession $adminSession "$BaseUrl/admin/giris" | Out-Null
    $adminLogin = Invoke-RestMethod -WebSession $adminSession -Method Post -Uri "$BaseUrl/api/v1/admin/auth/login" `
        -Headers @{'X-CSRF-Token' = (CookieValue $adminSession 'ankara_admin_pre_csrf')} -ContentType 'application/json' `
        -Body (JsonText @{email = "smoke-admin-$stamp@example.test"; password = $password})
    $adminCsrf = CookieValue $adminSession 'ankara_admin_csrf'
    Invoke-RestMethod -WebSession $adminSession -Method Put -Uri "$BaseUrl/api/v1/admin/listings/$($listing.data.id)/moderation" `
        -Headers @{'X-CSRF-Token' = $adminCsrf} -ContentType 'application/json' `
        -Body (JsonText @{status = 'active'; note = 'Canli smoke testi onayi'}) | Out-Null
    $mapInside = Invoke-RestMethod -Uri "$BaseUrl/api/v1/listings?map_only=1&limit=50&q=Live%20smoke&min_lat=39.80&max_lat=40.10&min_lng=32.70&max_lng=33.00"
    if ($listing.data.id -notin @($mapInside.data.items.id)) { throw 'Harita bbox sorgusu gorunen ilani dondurmedi.' }
    $mapOutside = Invoke-RestMethod -Uri "$BaseUrl/api/v1/listings?map_only=1&limit=50&q=Live%20smoke&min_lat=38.00&max_lat=38.50&min_lng=31.00&max_lng=31.50"
    if ($listing.data.id -in @($mapOutside.data.items.id)) { throw 'Harita bbox sorgusu gorunmeyen ilani dondurdu.' }
    $advanced = Invoke-RestMethod -Uri "$BaseUrl/api/v1/listings?map_only=1&limit=50&categories=home_technical&available_now=1&open_24_7=1&provider_kind=business&min_lat=39.80&max_lat=40.10&min_lng=32.70&max_lng=33.00"
    if ($listing.data.id -notin @($advanced.data.items.id)) { throw 'Gelismis kategori, musaitlik, 7/24 veya isletme filtresi ilani dondurmedi.' }
    $savedSearch = Invoke-RestMethod -WebSession $owner.Session -Method Post -Uri "$BaseUrl/api/v1/saved-searches" `
        -Headers @{'X-CSRF-Token' = $owner.Csrf} -ContentType 'application/json' `
        -Body (JsonText @{name = 'Smoke filtre'; notification_enabled = $true; filters = @{categories = @('home_technical','computer_it'); radius_meters = 20000; available_now = $true; open_24_7 = $true; provider_kind = 'business'}})
    $savedSearches = Invoke-RestMethod -WebSession $owner.Session -Uri "$BaseUrl/api/v1/saved-searches"
    if ($savedSearch.data.id -notin @($savedSearches.data.items.id)) { throw 'Kayitli arama listelenmedi.' }
    Invoke-RestMethod -WebSession $owner.Session -Method Delete -Uri "$BaseUrl/api/v1/saved-searches/$($savedSearch.data.id)" `
        -Headers @{'X-CSRF-Token' = $owner.Csrf} -ContentType 'application/json' -Body '{}' | Out-Null
    $detailHtml = Invoke-WebRequest -UseBasicParsing "$BaseUrl/ilan/$($listing.data.slug)"
    if ($detailHtml.Content -match '<script>alert\("xss"\)</script>') { throw 'Stored XSS HTML icinde escape edilmedi.' }
    ExpectStatus 404 {
        Invoke-RestMethod -WebSession $requester.Session -Method Put -Uri "$BaseUrl/api/v1/listings/$($listing.data.id)" `
            -Headers @{'X-CSRF-Token' = $requester.Csrf} -ContentType 'application/json' -Body (JsonText @{status = 'paused'})
    } 'Ilan IDOR'
    ExpectStatus 419 {
        Invoke-RestMethod -WebSession $requester.Session -Method Post -Uri "$BaseUrl/api/v1/conversations" `
            -Headers @{'X-CSRF-Token' = 'invalid-csrf-token'} -ContentType 'application/json' -Body (JsonText @{listing_id = $listing.data.id})
    } 'CSRF'
    $conversation = Invoke-RestMethod -WebSession $requester.Session -Method Post -Uri "$BaseUrl/api/v1/conversations" `
        -Headers @{'X-CSRF-Token' = $requester.Csrf} -ContentType 'application/json' -Body (JsonText @{listing_id = $listing.data.id})
    $conversationId = $conversation.data.conversation_id
    ExpectStatus 403 {
        Invoke-RestMethod -WebSession $admin.Session -Method Get -Uri "$BaseUrl/api/v1/conversations/$conversationId/messages"
    } 'Mesaj IDOR'
    $message = Invoke-RestMethod -WebSession $requester.Session -Method Post -Uri "$BaseUrl/api/v1/conversations/$conversationId/messages" `
        -Headers @{'X-CSRF-Token' = $requester.Csrf} -ContentType 'application/json' -Body (JsonText @{body = 'Live smoke notification message'})
    $phone = Invoke-RestMethod -WebSession $requester.Session -Method Post -Uri "$BaseUrl/api/v1/profiles/$ownerId/phone-reveal" `
        -Headers @{'X-CSRF-Token' = $requester.Csrf} -ContentType 'application/json' -Body '{}'
    if ($phone.data.phone_e164 -ne '+905321234567') { throw 'Telefon gizliligi/reveal akisi basarisiz.' }
    $realtime = Invoke-RestMethod -WebSession $owner.Session "$BaseUrl/api/v1/realtime/connection"
    if ($realtime.data.enabled -and (-not $realtime.data.url -or -not $realtime.data.token)) {
        throw 'Realtime etkin fakat baglanti bilgisi eksik.'
    }
    $review = Invoke-RestMethod -WebSession $requester.Session -Method Post -Uri "$BaseUrl/api/v1/reviews" `
        -Headers @{'X-CSRF-Token' = $requester.Csrf} -ContentType 'application/json' `
        -Body (JsonText @{listing_id = $listing.data.id; rating = 5; comment = 'Live smoke review'})
    $inbox = Invoke-RestMethod -WebSession $owner.Session "$BaseUrl/api/v1/notifications"
    if ($inbox.data.unread_count -lt 3) { throw 'Onay, mesaj ve degerlendirme bildirimleri olusmadi.' }
    $read = Invoke-RestMethod -WebSession $owner.Session -Method Post -Uri "$BaseUrl/api/v1/conversations/$conversationId/read" `
        -Headers @{'X-CSRF-Token' = $owner.Csrf} -ContentType 'application/json' -Body (JsonText @{message_id = $message.data.id})

    $stats = Invoke-RestMethod -WebSession $adminSession "$BaseUrl/api/v1/admin/stats"
    $privacy = Invoke-RestMethod -WebSession $requester.Session -Method Post -Uri "$BaseUrl/api/v1/privacy/requests" `
        -Headers @{'X-CSRF-Token' = $requester.Csrf} -ContentType 'application/json' `
        -Body (JsonText @{request_type = 'deletion'; details = 'Live smoke anonymization request'})
    Invoke-RestMethod -WebSession $adminSession -Method Put -Uri "$BaseUrl/api/v1/admin/privacy/requests/$($privacy.data.id)" `
        -Headers @{'X-CSRF-Token' = $adminCsrf} -ContentType 'application/json' -Body (JsonText @{status = 'completed'}) | Out-Null
    $anonymized = (& $psql -h $settings.DB_HOST -p $settings.DB_PORT -U $settings.DB_USER -d $settings.DB_NAME -t -A `
        -c "select (anonymized_at is not null)::text from users where id='$requesterId';").Trim()
    if ($anonymized -ne 'true') { throw 'Hesap anonimlestirilmedi.' }
    $listingDeletion = Invoke-RestMethod -WebSession $adminSession -Method Delete -Uri "$BaseUrl/api/v1/admin/listings/$($listing.data.id)" `
        -Headers @{'X-CSRF-Token' = $adminCsrf} -ContentType 'application/json' `
        -Body (JsonText @{reason = 'Live smoke kalici ilan silme testi'; confirmation = 'KALICI OLARAK SİL'})
    if (-not $listingDeletion.data.deleted) { throw 'Admin kalici ilan silme endpointi basarisiz.' }
    $userDeletion = Invoke-RestMethod -WebSession $adminSession -Method Delete -Uri "$BaseUrl/api/v1/admin/users/$requesterId" `
        -Headers @{'X-CSRF-Token' = $adminCsrf} -ContentType 'application/json' `
        -Body (JsonText @{reason = 'Live smoke kalici kullanici silme testi'; confirmation = 'KALICI OLARAK SİL'})
    if (-not $userDeletion.data.deleted) { throw 'Admin kalici kullanici silme endpointi basarisiz.' }
    $requesterExists = (& $psql -h $settings.DB_HOST -p $settings.DB_PORT -U $settings.DB_USER -d $settings.DB_NAME -t -A `
        -c "select count(*) from users where id='$requesterId';").Trim()
    if ($requesterExists -ne '0') { throw 'Kalici silinen kullanici veritabaninda kaldi.' }

    [pscustomobject]@{
        health = $health.data.database; listing = $listing.data.id; message = $message.data.id; review = $review.data.id;
        unread = $inbox.data.unread_count; read = $read.data.last_read_message_id;
        realtime = $(if ($realtime.data.enabled) { 'websocket' } else { 'polling' }); phone = 'private-reveal-ok';
        security = 'idor-csrf-admin-xss-ok'; map = 'bbox-limit-ok'; advanced_filters = 'categories-availability-business-ok';
        profile = 'unicode-business-preferences-ok'; saved_search = 'create-list-delete-ok';
        admin = $adminLogin.data.user.role; users = $stats.data.users; anonymized = $anonymized;
        hard_delete = 'listing-user-ok'
    } | ConvertTo-Json -Compress
}
finally {
    if ($conversationId) { Psql "delete from realtime_outbox where payload::text like '%$conversationId%'; delete from conversations where id='$conversationId';" | Out-Null }
    $ids = @($adminId, $ownerId, $requesterId) | Where-Object { $_ }
    if ($ids.Count -gt 0) {
        $quoted = ($ids | ForEach-Object { "'$_'" }) -join ','
        $channelQuoted = ($ids | ForEach-Object { "'user:$_'" }) -join ','
        Psql "delete from realtime_outbox where channel in ($channelQuoted); delete from analytics_events where user_id in ($quoted) or subject_id in ($quoted); delete from privacy_requests where user_id in ($quoted); delete from admin_audit_logs where admin_user_id in ($quoted); delete from users where id in ($quoted);" | Out-Null
    }
}
