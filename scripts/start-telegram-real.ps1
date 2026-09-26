param(
    [switch]$Model
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot/local-settings.ps1"

$token = Get-LocalSetting "TELEGRAM_REAL_BOT_TOKEN"
$webhookSecret = Get-LocalSetting "TELEGRAM_REAL_WEBHOOK_SECRET"
if ($token -notmatch '^\d+:[A-Za-z0-9_-]{20,}$') {
    throw "Set a valid TELEGRAM_REAL_BOT_TOKEN from BotFather in local .env."
}
if ($webhookSecret -notmatch '^[A-Za-z0-9_-]{32,256}$') {
    throw "TELEGRAM_REAL_WEBHOOK_SECRET must contain 32-256 characters: A-Z, a-z, 0-9, _ or -."
}

$env:TELEGRAM_REAL_BOT_TOKEN = $token
$env:TELEGRAM_REAL_WEBHOOK_SECRET = $webhookSecret
Initialize-LocalTelegramKey

& "$PSScriptRoot/start-local.ps1" -Apps -Model:$Model
if ($LASTEXITCODE -ne 0) { throw "The local stack did not start." }

$envFiles = @("--env-file", ".env.example", "--env-file", "config/versions.env")
if (Test-Path .env) { $envFiles += @("--env-file", ".env") }
$composeFiles = @("-f", "compose/compose.yaml")
$runningOnWindows = $PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows
if ($runningOnWindows) { $composeFiles += @("-f", "compose/windows.local.yaml") }
$composeFiles += @("-f", "compose/apps.local.yaml", "-f", "compose/telegram.real.yaml")
if ($Model) { $composeFiles += @("-f", "compose/model.local.yaml") }

& docker compose @envFiles @composeFiles --profile core --profile apps --profile telegram-real `
    up -d --no-deps --no-build --wait --force-recreate telegram-adapter cloudflared
if ($LASTEXITCODE -ne 0) { throw "Real Telegram mode did not start." }

$tunnelUrl = $null
for ($attempt = 0; $attempt -lt 30 -and -not $tunnelUrl; $attempt += 1) {
    Start-Sleep -Seconds 1
    $logs = & docker compose @envFiles @composeFiles --profile telegram-real logs --no-color cloudflared 2>&1
    $match = [regex]::Match(($logs -join "`n"), 'https://[a-z0-9-]+\.trycloudflare\.com')
    if ($match.Success) { $tunnelUrl = $match.Value }
}
if (-not $tunnelUrl) { throw "Cloudflare Quick Tunnel did not provide an HTTPS URL." }

$ready = $false
for ($attempt = 0; $attempt -lt 20 -and -not $ready; $attempt += 1) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "$tunnelUrl/health/ready" -TimeoutSec 5
        $ready = $response.StatusCode -eq 200
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $ready) { throw "The public webhook URL cannot reach Telegram Adapter." }

$apiUrl = "https://api.telegram.org/bot$token"
try {
    $bot = Invoke-RestMethod -Method Post -Uri "$apiUrl/getMe"
    if (-not $bot.ok -or -not $bot.result.username) { throw "invalid getMe" }
    $hook = Invoke-RestMethod -Method Post -Uri "$apiUrl/setWebhook" -ContentType "application/json" -Body (@{
        url = "$tunnelUrl/webhooks/telegram"
        secret_token = $webhookSecret
        allowed_updates = @("message", "callback_query")
        drop_pending_updates = $false
    } | ConvertTo-Json)
    if (-not $hook.ok) { throw "invalid setWebhook" }
    $info = Invoke-RestMethod -Method Post -Uri "$apiUrl/getWebhookInfo"
    if (-not $info.ok -or $info.result.url -ne "$tunnelUrl/webhooks/telegram") {
        throw "invalid getWebhookInfo"
    }
} catch {
    throw "Telegram Bot API rejected the bot token or temporary webhook. Secrets were not printed."
}

Write-Host "Real Telegram connected: @$($bot.result.username)"
Write-Host "Webhook: $tunnelUrl/webhooks/telegram"
Write-Host "Return to the fake API with: task telegram:real:down"
