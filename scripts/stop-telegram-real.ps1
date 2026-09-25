$ErrorActionPreference = "Stop"
. "$PSScriptRoot/local-settings.ps1"

$token = Get-LocalSetting "TELEGRAM_REAL_BOT_TOKEN"
if ($token -notmatch '^\d+:[A-Za-z0-9_-]{20,}$') {
    throw "Set a valid TELEGRAM_REAL_BOT_TOKEN from BotFather in local .env."
}

try {
    $result = Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$token/deleteWebhook" `
        -ContentType "application/json" -Body '{"drop_pending_updates":false}'
    if (-not $result.ok) { throw "invalid deleteWebhook" }
} catch {
    throw "Telegram Bot API did not remove the temporary webhook. The secret was not printed."
}

$envFiles = @("--env-file", ".env.example", "--env-file", "config/versions.env")
if (Test-Path .env) { $envFiles += @("--env-file", ".env") }
$composeFiles = @("-f", "compose/compose.yaml")
$runningOnWindows = $PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows
if ($runningOnWindows) { $composeFiles += @("-f", "compose/windows.local.yaml") }
$composeFiles += @("-f", "compose/apps.local.yaml")
& docker compose @envFiles @composeFiles --profile telegram-real stop cloudflared telegram-adapter
if ($LASTEXITCODE -ne 0) { throw "Failed to stop the temporary Telegram webhook." }

& "$PSScriptRoot/service-local.ps1" -Action Restart -Service telegram-adapter
if ($LASTEXITCODE -ne 0) { throw "Failed to return Telegram Adapter to the fake API." }
Write-Host "The temporary webhook was removed. Telegram Adapter uses the fake API again."
