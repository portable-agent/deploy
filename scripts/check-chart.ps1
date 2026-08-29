param(
    [string]$ChartPath = "charts/platform-base"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    throw "Helm не найден. Установи Helm 4.2.4 или запусти проверку в CI."
}

& helm lint $ChartPath --strict
if ($LASTEXITCODE -ne 0) {
    throw "helm lint завершился с ошибкой."
}

& helm template platform-base $ChartPath --namespace portable-agent-smoke --set environment=smoke | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "helm template завершился с ошибкой."
}

Write-Host "Helm chart прошёл lint и render."
