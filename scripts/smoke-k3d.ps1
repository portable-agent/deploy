param(
    [string]$ClusterName = "portable-agent-smoke",
    [string]$ChartPath = "charts/platform-base"
)

$ErrorActionPreference = "Stop"
$created = $false

foreach ($tool in @("docker", "k3d", "kubectl", "helm")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool не найден. Установи инструменты из README или запусти проверку в CI."
    }
}

$oldContext = (& kubectl config current-context 2>$null)
$oldExitCode = $LASTEXITCODE
if ($oldExitCode -ne 0) {
    $oldContext = $null
}

try {
    $oldCluster = & k3d cluster list --no-headers 2>$null | Select-String "^$([regex]::Escape($ClusterName))\s"
    if ($oldCluster) {
        throw "Кластер $ClusterName уже существует. Скрипт не будет менять чужой кластер."
    }

    & k3d cluster create $ClusterName --agents 1 --wait --kubeconfig-switch-context=false
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось создать k3d-кластер."
    }
    $created = $true

    $context = "k3d-$ClusterName"
    & helm upgrade --install platform-base $ChartPath `
        --kube-context $context `
        --namespace portable-agent-smoke `
        --create-namespace `
        --set environment=smoke `
        --wait
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось установить Helm chart."
    }

    $ready = & kubectl --context $context `
        --namespace portable-agent-smoke `
        get configmap platform-base-info `
        -o 'jsonpath={.data.ready}'
    if ($ready -ne "true") {
        throw "Smoke-проверка ожидала ready=true, получено: $ready"
    }

    Write-Host "Helm chart успешно установлен и проверен в k3d."
}
finally {
    if ($created) {
        & k3d cluster delete $ClusterName
    }
    if ($oldContext) {
        & kubectl config use-context $oldContext | Out-Null
    }
}
