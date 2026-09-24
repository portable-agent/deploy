function Get-LocalSetting([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    foreach ($path in @(".env", ".env.example")) {
        if ($value -or -not (Test-Path -LiteralPath $path)) { continue }
        $line = Get-Content -LiteralPath $path | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
        if ($line) { $value = $line.Substring($line.IndexOf('=') + 1) }
    }
    if (-not $value) { throw "Не задан $Name." }
    return $value
}

function Initialize-LocalTelegramKey {
    $key = Get-LocalSetting "TELEGRAM_TOKEN_KEY_BASE64"
    if ($key -ne "derive-from-local-webhook-secret") { return }

    $webhookSecret = Get-LocalSetting "TELEGRAM_WEBHOOK_SECRET"
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes("portable-agent-local:$webhookSecret")
        $env:TELEGRAM_TOKEN_KEY_BASE64 = [Convert]::ToBase64String($hash.ComputeHash($bytes))
    } finally {
        $hash.Dispose()
    }
}
