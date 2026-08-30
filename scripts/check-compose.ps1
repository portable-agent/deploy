$ErrorActionPreference = "Stop"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker не найден. Запусти проверку в CI или установи Docker Desktop."
}
& docker compose --env-file .env.example --env-file config/versions.env -f compose/compose.yaml --profile core --profile observe config --quiet
if ($LASTEXITCODE -ne 0) { throw "Compose config содержит ошибку." }
Write-Host "Compose config прошёл проверку."

