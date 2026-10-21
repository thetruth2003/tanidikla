$ErrorActionPreference = 'Stop'

$phpExecutable = (Get-Command php -ErrorAction SilentlyContinue).Source
if (-not $phpExecutable) {
    $phpExecutable = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\PHP.PHP.*\php.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $phpExecutable) {
    throw 'PHP bulunamadı. Önce PHP kurulumu yapılmalı.'
}

$phpDirectory = Split-Path -Parent $phpExecutable
$env:PHP_EXTENSION_DIR = Join-Path $phpDirectory 'ext'

$pgData = Join-Path $PSScriptRoot 'storage\postgres\data'
if (Test-Path (Join-Path $pgData 'PG_VERSION')) {
    $pgIsReady = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\pg_isready.exe' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if ($pgIsReady) {
        & $pgIsReady -h 127.0.0.1 -p 5432 *> $null
        if ($LASTEXITCODE -ne 0) {
            $pgCtl = Join-Path (Split-Path -Parent $pgIsReady) 'pg_ctl.exe'
            & $pgCtl -D $pgData -l (Join-Path $PSScriptRoot 'storage\logs\postgres.log') start
        }
    }
}

& $phpExecutable -c (Join-Path $PSScriptRoot 'php.ini') -S '127.0.0.1:8080' -t (Join-Path $PSScriptRoot 'public') (Join-Path $PSScriptRoot 'router.php')
