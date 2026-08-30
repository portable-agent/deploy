param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Image,
    [int]$Port = 8080,
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
if ($Name -notmatch '^[a-z][a-z0-9-]{1,61}[a-z0-9]$') {
    throw "Name должен быть DNS-именем: маленькие латинские буквы, цифры и дефис."
}
if ($Image -notmatch '^[a-zA-Z0-9._/-]+$') { throw "Image содержит недопустимые символы." }
if ($Port -lt 1 -or $Port -gt 65535) { throw "Port должен быть от 1 до 65535." }

$catalogPath = Join-Path $Root "services/catalog.json"
$environmentPath = Join-Path $Root "environments/environments.json"
$catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
$environmentList = Get-Content $environmentPath -Raw | ConvertFrom-Json
if ($catalog.items.name -contains $Name) { throw "Сервис $Name уже зарегистрирован." }

foreach ($environment in $environmentList.items) {
    $folder = Join-Path $Root "environments/$($environment.name)/services/$Name"
    if (Test-Path $folder) { throw "Папка уже существует: $folder" }
}

foreach ($environment in $environmentList.items) {
    $folder = Join-Path $Root "environments/$($environment.name)/services/$Name"
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $values = @"
fullnameOverride: $Name
replicaCount: $($environment.replicas)
image:
  repository: $Image
  tag: change-me
containerPort: $Port
service:
  port: 80
config:
  APP_ENV: $($environment.name)
secretRefs: []
"@
    Set-Content -Path (Join-Path $folder "values.yaml") -Value $values -Encoding utf8NoBOM
}

$catalog.items += [pscustomobject]@{ name = $Name; image = $Image; port = $Port }
$catalog.items = @($catalog.items | Sort-Object name)
$catalog | ConvertTo-Json -Depth 10 | Set-Content $catalogPath -Encoding utf8NoBOM
Write-Host "Сервис $Name добавлен во все окружения. Проверь tag и secretRefs перед commit."

