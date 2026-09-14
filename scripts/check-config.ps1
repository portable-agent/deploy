$ErrorActionPreference = "Stop"
& "$PSScriptRoot/check-chart.ps1"
& "$PSScriptRoot/test-new-service.ps1"
if (Get-Command docker -ErrorAction SilentlyContinue) { & "$PSScriptRoot/check-compose.ps1" }

$secretPatterns = @('ghp_[A-Za-z0-9]+', 'github_pat_', 'AKIA[0-9A-Z]{16}', '-----BEGIN .*PRIVATE KEY-----')
$files = & git ls-files | Where-Object { $_ -ne 'scripts/check-config.ps1' -and (Test-Path -LiteralPath $_) }
foreach ($pattern in $secretPatterns) {
    if ($files | Select-String -Pattern $pattern -Quiet) { throw "Найден фрагмент, похожий на секрет: $pattern" }
}
Write-Host "Быстрые проверки инфраструктуры прошли."
