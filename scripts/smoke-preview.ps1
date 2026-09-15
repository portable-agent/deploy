param(
    [Parameter(Mandatory)]
    [ValidateRange(1, 999999999)]
    [int]$PullRequestNumber,
    [string]$ClusterName = ""
)

$ErrorActionPreference = "Stop"
$created = $false
$namespaceCreated = $false
$namespace = "portable-agent-pr-$PullRequestNumber"
if (-not $ClusterName) { $ClusterName = "pa-preview-$PullRequestNumber" }
if ($ClusterName -notmatch '^[a-z0-9][a-z0-9-]{0,39}$') {
    throw "ClusterName must contain lowercase letters, numbers and hyphens only."
}

foreach ($tool in @("docker", "k3d", "kubectl", "helm")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is not installed."
    }
}

$oldContext = (& kubectl config current-context 2>$null)
if ($LASTEXITCODE -ne 0) { $oldContext = $null }

try {
    $oldCluster = & k3d cluster list --no-headers 2>$null | Select-String "^$([regex]::Escape($ClusterName))\s"
    if ($oldCluster) { throw "Cluster $ClusterName already exists and will not be changed." }

    & k3d cluster create $ClusterName --agents 1 --wait --kubeconfig-switch-context=false
    if ($LASTEXITCODE -ne 0) { throw "Cannot create k3d cluster." }
    $created = $true
    $context = "k3d-$ClusterName"
    $expiresAt = (Get-Date).ToUniversalTime().AddHours(2).ToString("yyyy-MM-ddTHH:mm:ssZ")

    & helm upgrade --install "preview-$PullRequestNumber" charts/preview `
        --kube-context $context `
        --namespace kube-system `
        --set "namespace.name=$namespace" `
        --set-string "namespace.pullRequest=$PullRequestNumber" `
        --set-string "namespace.expiresAt=$expiresAt" `
        --wait
    if ($LASTEXITCODE -ne 0) { throw "Cannot install preview guardrails." }
    $namespaceCreated = $true

    $environment = & kubectl --context $context get namespace $namespace `
        -o 'jsonpath={.metadata.labels.portable-agent\.io/environment}'
    $pullRequest = & kubectl --context $context get namespace $namespace `
        -o 'jsonpath={.metadata.labels.portable-agent\.io/pull-request}'
    if ($environment -ne "preview" -or $pullRequest -ne "$PullRequestNumber") {
        throw "Preview namespace labels are invalid."
    }

    foreach ($resource in @("ResourceQuota/preview-budget", "LimitRange/preview-limits", "NetworkPolicy/preview-default-deny")) {
        & kubectl --context $context --namespace $namespace get $resource | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Preview guardrail is missing: $resource" }
    }

    & helm upgrade --install preview-service charts/service `
        --kube-context $context `
        --namespace $namespace `
        --values charts/service/tests/smoke-values.yaml `
        --wait
    if ($LASTEXITCODE -ne 0) { throw "Cannot install service chart into preview namespace." }

    & kubectl --context $context --namespace $namespace `
        rollout status deployment/smoke-service --timeout=90s
    if ($LASTEXITCODE -ne 0) { throw "Preview service did not become Ready." }

    Write-Host "Preview namespace $namespace passed guardrail and deployment checks."
}
finally {
    if ($namespaceCreated -and $created) {
        & kubectl --context "k3d-$ClusterName" delete namespace $namespace --wait --timeout=60s | Out-Null
    }
    if ($created) { & k3d cluster delete $ClusterName }
    if ($oldContext) { & kubectl config use-context $oldContext | Out-Null }
}
