$ErrorActionPreference = "Stop"

if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    throw "Helm не найден. Установи Helm 4.2.4 или запусти проверку в CI."
}

foreach ($item in @(
    @{ Name = "platform-base"; Path = "charts/platform-base"; Args = @("--set", "environment=smoke") },
    @{ Name = "service"; Path = "charts/service"; Args = @("-f", "charts/service/tests/smoke-values.yaml") },
    @{ Name = "gitops"; Path = "charts/gitops"; Args = @("-f", "charts/gitops/tests/smoke-values.yaml") }
)) {
    & helm lint $item.Path --strict @($item.Args)
    if ($LASTEXITCODE -ne 0) { throw "helm lint $($item.Name) завершился с ошибкой." }
    & helm template $item.Name $item.Path --namespace portable-agent-smoke @($item.Args) | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "helm template $($item.Name) завершился с ошибкой." }
}

Write-Host "Все Helm charts прошли lint и render."
