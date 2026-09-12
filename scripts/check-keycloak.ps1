param(
    [Parameter(Mandatory = $true)][string]$BaseUrl,
    [Parameter(Mandatory = $true)][string]$ServiceSecret,
    [Parameter(Mandatory = $true)][string]$ExpectedTenant
)
$ErrorActionPreference = "Stop"

$realm = Get-Content -Raw -LiteralPath "compose/keycloak/portable-agent-realm.json" | ConvertFrom-Json
$client = $realm.clients | Where-Object clientId -eq "portable-agent-local"
$user = $realm.users | Where-Object username -eq "local-user"
$password = ($user.credentials | Where-Object type -eq "password").value
$serviceClient = $realm.clients | Where-Object clientId -eq "action-service"

try {
    $tokenResponse = Invoke-RestMethod -Method Post `
        -Uri "$BaseUrl/realms/$($realm.realm)/protocol/openid-connect/token" `
        -Body @{
            client_id = $client.clientId
            username = $user.username
            password = $password
            grant_type = "password"
        }
    $payload = $tokenResponse.access_token.Split('.')[1].Replace('-', '+').Replace('_', '/')
    $payload += '=' * ((4 - $payload.Length % 4) % 4)
    $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
    $audiences = @($claims.aud)
    $scopes = @($claims.scope -split ' ')
    if ($claims.sub -ne $user.id -or $claims.tenant_id -ne $ExpectedTenant `
        -or $audiences -notcontains "action-service" `
        -or $audiences -notcontains "calendar-mcp" -or $scopes -notcontains "calendar:write") {
        throw "JWT claims не совпадают с локальным fixture."
    }

    $serviceToken = Invoke-RestMethod -Method Post `
        -Uri "$BaseUrl/realms/$($realm.realm)/protocol/openid-connect/token" `
        -Body @{
            client_id = $serviceClient.clientId
            client_secret = $ServiceSecret
            grant_type = "client_credentials"
        }
    $servicePayload = $serviceToken.access_token.Split('.')[1].Replace('-', '+').Replace('_', '/')
    $servicePayload += '=' * ((4 - $servicePayload.Length % 4) % 4)
    $serviceClaims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($servicePayload)) | ConvertFrom-Json
    $serviceAudiences = @($serviceClaims.aud)
    $serviceScopes = @($serviceClaims.scope -split ' ')
    if ($serviceClaims.tenant_id -ne $ExpectedTenant `
        -or $serviceAudiences -notcontains "mcp-gateway" `
        -or $serviceAudiences -notcontains "calendar-mcp" `
        -or $serviceScopes -notcontains "mcp:call" `
        -or $serviceScopes -notcontains "calendar:write") {
        throw "Service token action-service не содержит нужные claims."
    }
} catch {
    throw "Локальный Keycloak не соответствует compose/keycloak/portable-agent-realm.json. Для обновления тестовых данных выполни 'pwsh ./scripts/stop-local.ps1 -DeleteData', затем запусти стенд снова. Причина: $($_.Exception.Message)"
}

Write-Host "Keycloak fixture прошёл runtime-проверку."
