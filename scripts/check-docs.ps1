$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "README.md",
    "AGENTS.md",
    "catalog-info.yaml",
    "mkdocs.yml",
    "docs/index.md",
    "docs/architecture.md",
    "docs/development.md",
    "docs/runbook.md",
    "docs/decisions/0001-deploy-repository.md",
    "docs/decisions/0003-taskfile-workflow.md",
    "docs/decisions/0004-test-lab-ownership.md",
    "docs/decisions/0005-pr-preview.md"
)

$missing = $requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }
if ($missing.Count -gt 0) {
    throw "Нет обязательных файлов: $($missing -join ', ')"
}

$catalog = Get-Content -LiteralPath "catalog-info.yaml" -Raw
if ($catalog -notmatch "backstage\.io/techdocs-ref:\s*dir:\.") {
    throw "В catalog-info.yaml нет backstage.io/techdocs-ref: dir:."
}

Write-Host "Документация deploy соответствует стандарту."
