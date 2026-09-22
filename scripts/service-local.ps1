param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Status", "Stop", "Restart", "Logs")]
    [string]$Action,
    [ValidateSet("channel-gateway", "agent-runtime", "action-service", "conversation-service", "mcp-gateway", "calendar-mcp")]
    [string]$Service,
    [ValidateRange(1, 10000)]
    [int]$Tail = 100
)

$ErrorActionPreference = "Stop"
if ($Action -ne "Status" -and -not $Service) {
    throw "Для команды $Action укажи -Service."
}

$envFiles = @("--env-file", ".env.example", "--env-file", "config/versions.env")
if (Test-Path .env) { $envFiles += @("--env-file", ".env") }
$composeFiles = @("-f", "compose/compose.yaml")
$runningOnWindows = $PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows
if ($runningOnWindows) { $composeFiles += @("-f", "compose/windows.local.yaml") }
$composeFiles += @("-f", "compose/apps.local.yaml")
$profiles = @("--profile", "core", "--profile", "apps")

switch ($Action) {
    "Status" {
        & docker compose @envFiles @composeFiles @profiles ps
    }
    "Stop" {
        & docker compose @envFiles @composeFiles @profiles stop $Service
    }
    "Restart" {
        & docker compose @envFiles @composeFiles @profiles up -d --build --wait $Service
    }
    "Logs" {
        & docker compose @envFiles @composeFiles @profiles logs --tail $Tail --follow $Service
    }
}

if ($LASTEXITCODE -ne 0) { throw "Команда $Action для локального окружения завершилась с ошибкой." }
