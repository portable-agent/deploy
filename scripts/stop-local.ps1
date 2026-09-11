param([switch]$DeleteData)
$ErrorActionPreference = "Stop"
$args = @("compose", "--env-file", ".env.example", "--env-file", "config/versions.env")
if (Test-Path .env) { $args += @("--env-file", ".env") }
$args += @("-f", "compose/compose.yaml")
if ($IsWindows) { $args += @("-f", "compose/windows.local.yaml") }
$args += @("--profile", "core", "--profile", "observe", "--profile", "apps", "down")
if ($DeleteData) { $args += "--volumes" }
& docker @args
if ($LASTEXITCODE -ne 0) { throw "Не удалось остановить локальную инфраструктуру." }
