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

function Get-AppNetwork {
    $projectName = Get-LocalSetting "COMPOSE_PROJECT_NAME"
    $containerIds = @(
        (& docker ps `
            --filter "label=com.docker.compose.project=$projectName" `
            --filter "label=com.docker.compose.service=channel-gateway" `
            --format "{{.ID}}") | Where-Object { $_ }
    )
    if ($LASTEXITCODE -ne 0 -or $containerIds.Count -ne 1) {
        throw "Expected one running Channel Gateway container in Compose project $projectName."
    }

    $networksJson = & docker inspect --format '{{json .NetworkSettings.Networks}}' $containerIds[0]
    if ($LASTEXITCODE -ne 0 -or -not $networksJson) {
        throw "Cannot inspect the Channel Gateway network."
    }
    $networkNames = @(($networksJson | ConvertFrom-Json).PSObject.Properties.Name)
    if ($networkNames.Count -ne 1) {
        throw "Expected Channel Gateway to use exactly one Compose network."
    }
    return $networkNames[0]
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
    CHANNEL_URL = "http://channel-gateway:8080"
    ACTION_URL = "http://action-service:8080"
    CALENDAR_TEST_URL = "http://calendar-mcp:8080"
    DOCKER_NETWORK = Get-AppNetwork
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
