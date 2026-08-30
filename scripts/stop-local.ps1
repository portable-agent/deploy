param([switch]$DeleteData)
$ErrorActionPreference = "Stop"
$args = @("compose", "--env-file", ".env.example", "--env-file", "config/versions.env")
if (Test-Path .env) { $args += @("--env-file", ".env") }
$args += @("-f", "compose/compose.yaml", "--profile", "core", "--profile", "observe", "down")
if ($DeleteData) { $args += "--volumes" }
& docker @args
if ($LASTEXITCODE -ne 0) { throw "Не удалось остановить локальную инфраструктуру." }
