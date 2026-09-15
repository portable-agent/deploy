$ErrorActionPreference = "Stop"

$requiredFiles = @(
    "charts/preview/Chart.yaml",
    "charts/preview/values.yaml",
    "charts/preview/values.schema.json",
    "charts/preview/templates/namespace.yaml",
    "charts/preview/templates/resourcequota.yaml",
    "charts/preview/templates/limitrange.yaml",
    "charts/preview/templates/networkpolicy.yaml",
    "scripts/smoke-preview.ps1",
    ".github/workflows/preview-smoke.yml"
)
foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Required preview file is missing: $file" }
}

$namespace = Get-Content -Raw -LiteralPath "charts/preview/templates/namespace.yaml"
foreach ($required in @("kind: Namespace", "portable-agent.io/environment", "portable-agent.io/pull-request", "portable-agent.io/expires-at")) {
    if ($namespace -notmatch [regex]::Escape($required)) { throw "Preview namespace does not contain $required." }
}

$quota = Get-Content -Raw -LiteralPath "charts/preview/templates/resourcequota.yaml"
foreach ($required in @("kind: ResourceQuota", "requests.cpu", "requests.memory", "limits.cpu", "limits.memory", "pods")) {
    if ($quota -notmatch [regex]::Escape($required)) { throw "Preview quota does not contain $required." }
}

$limit = Get-Content -Raw -LiteralPath "charts/preview/templates/limitrange.yaml"
foreach ($required in @("kind: LimitRange", "defaultRequest", "default")) {
    if ($limit -notmatch [regex]::Escape($required)) { throw "Preview limits do not contain $required." }
}

$policy = Get-Content -Raw -LiteralPath "charts/preview/templates/networkpolicy.yaml"
foreach ($required in @("kind: NetworkPolicy", "podSelector: {}", "policyTypes", "Ingress", "Egress")) {
    if ($policy -notmatch [regex]::Escape($required)) { throw "Preview network policy does not contain $required." }
}

$smoke = Get-Content -Raw -LiteralPath "scripts/smoke-preview.ps1"
foreach ($required in @("PullRequestNumber", "portable-agent-pr-", "charts/preview", "charts/service", "ResourceQuota", "LimitRange", "NetworkPolicy", "k3d cluster delete")) {
    if ($smoke -notmatch [regex]::Escape($required)) { throw "Preview smoke does not contain $required." }
}

$workflow = Get-Content -Raw -LiteralPath ".github/workflows/preview-smoke.yml"
foreach ($required in @("pull_request", "github.event.pull_request.number", "smoke-preview.ps1", "K3D_VERSION", "helm")) {
    if ($workflow -notmatch [regex]::Escape($required)) { throw "Preview workflow does not contain $required." }
}

$taskfile = Get-Content -Raw -LiteralPath "Taskfile.yml"
if ($taskfile -notmatch '(?m)^  preview:smoke:') { throw "Taskfile does not contain preview:smoke." }

Write-Host "Preview structure checks passed."
