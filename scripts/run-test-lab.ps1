param([string]$TestLabPath = "")

$ErrorActionPreference = "Stop"

function Get-LocalSetting([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    foreach ($path in @(".env", ".env.example")) {
        if ($value -or -not (Test-Path -LiteralPath $path)) { continue }
        $line = Get-Content -LiteralPath $path | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
        if ($line) { $value = $line.Substring($line.IndexOf('=') + 1) }
    }
    if (-not $value) { throw "Set $Name in the environment or local .env file." }
    return $value
}

if (-not $TestLabPath) { $TestLabPath = Get-LocalSetting "TEST_LAB_PATH" }
$resolvedTestLabPath = (Resolve-Path -LiteralPath $TestLabPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $resolvedTestLabPath "Taskfile.yml"))) {
    throw "TEST_LAB_PATH must point to the portable-agent test-lab repository."
}

$taskCommand = Get-Command task -ErrorAction SilentlyContinue
if (-not $taskCommand) { throw "Task is not installed. Run 'winget install Task.Task'." }

$realm = Get-Content -Raw -LiteralPath "compose/keycloak/portable-agent-realm.json" | ConvertFrom-Json
$client = $realm.clients | Where-Object clientId -eq "portable-agent-local"
$user = $realm.users | Where-Object username -eq "local-user"
$password = ($user.credentials | Where-Object type -eq "password").value
if (-not $client -or -not $user -or -not $password) {
    throw "Local Keycloak fixture does not contain the test client and user."
}

$settings = @{
    KEYCLOAK_URL = "http://localhost:$(Get-LocalSetting 'KEYCLOAK_PORT')"
    CHANNEL_URL = "http://host.docker.internal:$(Get-LocalSetting 'CHANNEL_GATEWAY_PORT')"
    ACTION_URL = "http://host.docker.internal:$(Get-LocalSetting 'ACTION_SERVICE_PORT')"
    CALENDAR_TEST_URL = "http://host.docker.internal:$(Get-LocalSetting 'CALENDAR_MCP_PORT')"
    OIDC_REALM = $realm.realm
    OIDC_CLIENT_ID = $client.clientId
    TEST_USERNAME = $user.username
    TEST_PASSWORD = $password
    CALENDAR_TEST_API_KEY = Get-LocalSetting "CALENDAR_TEST_API_KEY"
}

$oldSettings = @{}
try {
    foreach ($name in $settings.Keys) {
        $oldSettings[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, $settings[$name], "Process")
    }
    & $taskCommand.Source --dir $resolvedTestLabPath test:e2e
    if ($LASTEXITCODE -ne 0) { throw "Test Lab acceptance scenario failed." }
}
finally {
    foreach ($name in $settings.Keys) {
        [Environment]::SetEnvironmentVariable($name, $oldSettings[$name], "Process")
    }
}
