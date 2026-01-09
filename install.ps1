# Frontier Framework - Windows Installer
$repoUrl = "https://github.com/frontier-org/frontier.git"
$destFolder = "frontier-app"

Write-Host "🌐 Installing Frontier Framework..." -ForegroundColor Cyan

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: Git is not installed. Please install Git and try again." -ForegroundColor Red
    exit
}

if (Test-Path $destFolder) {
    Write-Host "⚠️ Folder '$destFolder' already exists." -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Path $destFolder | Out-Null
}

Set-Location $destFolder

git init | Out-Null
git remote add origin $repoUrl | Out-Null
git config core.sparseCheckout true

".frontier/*" | Out-File -FilePath .git/info/sparse-checkout -Encoding utf8
"*.bat" | Out-File -Append -FilePath .git/info/sparse-checkout -Encoding utf8

Write-Host "📥 Downloading engine components..." -ForegroundColor Gray
git pull origin main --quiet --depth 1 | Out-Null

Remove-Item -Recurse -Force .git

Write-Host "`n✅ Frontier installed successfully in: $destFolder" -ForegroundColor Green
Write-Host "🚀 Run 'cd $destFolder' and '.\frontier dev' to start." -ForegroundColor Cyan