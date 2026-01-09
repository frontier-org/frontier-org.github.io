$ErrorActionPreference = "Stop"
$repoUrl = "https://github.com/frontier-org/frontier.git"
$destFolder = "frontier-app"

Write-Host "`n🌐 Frontier Framework Installer" -ForegroundColor Cyan

try {
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git not found. Install it from https://git-scm.com"
    }

    if (!(Test-Path $destFolder)) { New-Item -ItemType Directory -Path $destFolder | Out-Null }
    Set-Location $destFolder

    Write-Host "📥 Downloading components..." -ForegroundColor Gray
    git init -q
    git remote add origin $repoUrl
    git config core.sparseCheckout true

    ".frontier/*", "app/*", "modules/*", "*.bat", "frontier.toml" | Out-File -FilePath .git/info/sparse-checkout -Encoding utf8

    git pull origin main --quiet --depth 1

    Remove-Item -Recurse -Force .git -ErrorAction SilentlyContinue

    Write-Host "`n✅ Success! Project created in /$destFolder" -ForegroundColor Green
    Write-Host "👉 Run: cd $destFolder ; .\frontier dev" -ForegroundColor Cyan

} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}