$ErrorActionPreference = "Stop"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pa-service-" + [guid]::NewGuid())
try {
    New-Item -ItemType Directory -Path "$tempRoot/services", "$tempRoot/environments" | Out-Null
    Copy-Item "$PSScriptRoot/../services/catalog.json" "$tempRoot/services/catalog.json"
    Copy-Item "$PSScriptRoot/../environments/environments.json" "$tempRoot/environments/environments.json"
    & "$PSScriptRoot/new-service.ps1" -Name sample-api -Image ghcr.io/example/sample-api -Port 8080 -Root $tempRoot
    foreach ($envName in @("local", "dev", "stage")) {
        if (-not (Test-Path "$tempRoot/environments/$envName/services/sample-api/values.yaml")) {
            throw "Нет values для $envName."
        }
    }
    $duplicateFailed = $false
    try { & "$PSScriptRoot/new-service.ps1" -Name sample-api -Image ghcr.io/example/sample-api -Root $tempRoot } catch { $duplicateFailed = $true }
    if (-not $duplicateFailed) { throw "Повторная регистрация должна завершаться ошибкой." }
    Write-Host "Генератор нового сервиса прошёл тест."
}
finally {
    if (Test-Path $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
