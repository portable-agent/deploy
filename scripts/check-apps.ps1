param([int]$TimeoutSeconds = 30)
$ErrorActionPreference = "Stop"

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

function Test-SameDateTime([string]$Actual, [string]$Expected) {
    try {
        $style = [Globalization.DateTimeStyles]::RoundtripKind
        $culture = [Globalization.CultureInfo]::InvariantCulture
        $actualDate = [DateTimeOffset]::Parse($Actual, $culture, $style)
        $expectedDate = [DateTimeOffset]::Parse($Expected, $culture, $style)
        return $actualDate.UtcDateTime -eq $expectedDate.UtcDateTime `
            -and $actualDate.Offset -eq $expectedDate.Offset
    } catch {
        return $false
    }
}

$realm = Get-Content -Raw -LiteralPath "compose/keycloak/portable-agent-realm.json" | ConvertFrom-Json
$client = $realm.clients | Where-Object clientId -eq "portable-agent-local"
$user = $realm.users | Where-Object username -eq "local-user"
$password = ($user.credentials | Where-Object type -eq "password").value
$keycloakUrl = "http://localhost:$(Get-LocalSetting 'KEYCLOAK_PORT')"
$agentUrl = "http://localhost:$(Get-LocalSetting 'AGENT_RUNTIME_PORT')"
$actionUrl = "http://localhost:$(Get-LocalSetting 'ACTION_SERVICE_PORT')"
$calendarUrl = "http://localhost:$(Get-LocalSetting 'CALENDAR_MCP_PORT')"

$token = (Invoke-RestMethod -Method Post `
    -Uri "$keycloakUrl/realms/$($realm.realm)/protocol/openid-connect/token" `
    -Body @{
        client_id = $client.clientId
        username = $user.username
        password = $password
        grant_type = "password"
    }).access_token
$headers = @{ Authorization = "Bearer $token" }
$requestKey = "compose-check-$([guid]::NewGuid().ToString('N'))"
$payload = @{
    title = "Compose check"
    startAt = "2026-09-12T10:00:00+03:00"
    endAt = "2026-09-12T10:30:00+03:00"
    timeZone = "Europe/Moscow"
}
$proposalRequest = @{
    text = "Создай встречу `"$($payload.title)`" с $($payload.startAt) до $($payload.endAt)"
    context = @{
        timeZone = $payload.timeZone
        availableConnectors = @("fake-calendar")
    }
} | ConvertTo-Json -Depth 5
$proposalResult = Invoke-RestMethod -Method Post -Uri "$agentUrl/api/v1/proposals" `
    -Headers $headers -ContentType "application/json" -Body $proposalRequest
$proposal = $proposalResult.proposal
if (-not $proposal -or $proposalResult.clarification -or -not $proposal.requiresApproval `
    -or $proposal.kind -ne "calendar.create_event" -or $proposal.connector -ne "fake-calendar" `
    -or $proposal.payload.title -ne $payload.title `
    -or -not (Test-SameDateTime $proposal.payload.startAt $payload.startAt) `
    -or -not (Test-SameDateTime $proposal.payload.endAt $payload.endAt) `
    -or $proposal.payload.timeZone -ne $payload.timeZone) {
    throw "Agent Runtime не создал ожидаемое предложение."
}
$body = @{
    kind = $proposal.kind
    connector = $proposal.connector
    requestKey = $requestKey
    payload = $proposal.payload
} | ConvertTo-Json -Depth 5
$action = Invoke-RestMethod -Method Post -Uri "$actionUrl/api/v1/actions" `
    -Headers $headers -ContentType "application/json" -Body $body
$decision = @{ decision = "CONFIRM"; payloadHash = $action.payloadHash } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$actionUrl/api/v1/actions/$($action.id)/decisions" `
    -Headers $headers -ContentType "application/json" -Body $decision | Out-Null

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
    Start-Sleep -Milliseconds 500
    $saved = Invoke-RestMethod -Method Get -Uri "$actionUrl/api/v1/actions/$($action.id)" -Headers $headers
} while ($saved.status -notin @("SUCCEEDED", "FAILED") -and (Get-Date) -lt $deadline)
if ($saved.status -ne "SUCCEEDED") {
    throw "Action $($action.id) не выполнен за $TimeoutSeconds секунд: $($saved.status)."
}
if (-not (Test-SameDateTime $saved.payload.startAt $payload.startAt) `
    -or -not (Test-SameDateTime $saved.payload.endAt $payload.endAt) `
    -or $saved.payload.timeZone -ne $payload.timeZone) {
    throw "Action Service изменил время или часовой пояс подтверждённого payload."
}

$eventResponse = Invoke-RestMethod -Method Get -Uri "$calendarUrl/test/events?requestKey=$requestKey" `
    -Headers @{ "X-Test-Key" = Get-LocalSetting "CALENDAR_TEST_API_KEY" }
$events = @($eventResponse.events)
$event = $events[0]
if ($events.Count -ne 1 -or $event.eventId -ne $saved.result.eventId `
    -or $event.requestKey -ne $requestKey -or $event.title -ne $payload.title `
    -or -not (Test-SameDateTime $event.startAt $payload.startAt) `
    -or -not (Test-SameDateTime $event.endAt $payload.endAt) `
    -or $event.timeZone -ne $payload.timeZone) {
    throw "Calendar MCP не сохранил ожидаемое событие."
}

Write-Host "Полный срез работает: proposal $($proposal.proposalId), action $($action.id), event $($saved.result.eventId)."
