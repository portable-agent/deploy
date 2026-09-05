param([Parameter(Mandatory = $true)][string]$BaseUrl)
$ErrorActionPreference = "Stop"

$realm = Get-Content -Raw -LiteralPath "compose/keycloak/portable-agent-realm.json" | ConvertFrom-Json
$client = $realm.clients | Where-Object clientId -eq "portable-agent-local"
$user = $realm.users | Where-Object username -eq "local-user"
$password = ($user.credentials | Where-Object type -eq "password").value
$tenantId = $user.attributes.tenant_id[0]

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
    if ($claims.sub -ne $user.id -or $claims.tenant_id -ne $tenantId) {
        throw "JWT claims не совпадают с локальным fixture."
    }
} catch {
    throw "Локальный Keycloak не соответствует compose/keycloak/portable-agent-realm.json. Для обновления тестовых данных выполни 'pwsh ./scripts/stop-local.ps1 -DeleteData', затем запусти стенд снова. Причина: $($_.Exception.Message)"
}

Write-Host "Keycloak fixture прошёл runtime-проверку."
