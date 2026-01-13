$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 3072

# Boolean to toggle between Pre-release and Stable
$UsePrerelease = $true

$repo = "frontier-org/frontier"
$tempDir = "C:\Temp"
$zip = Join-Path $tempDir "Frontier.zip"

if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }

Write-Host "`n* Frontier Installer *`n" -ForegroundColor Cyan
$userInput = Read-Host "Project folder name (Leave empty for current folder)"
$dest = if($userInput){$userInput}else{(Get-Location).Path}

if(!(Test-Path "$dest")){ New-Item -ItemType Directory -Path "$dest" -Force | Out-Null }
$destFull = (Resolve-Path "$dest").Path

try {
    Write-Host "`nFetching release info..." -ForegroundColor Gray
    
    if ($UsePrerelease) {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases"
        $targetRelease = $releases | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
        
        if ($null -eq $targetRelease) {
            Write-Host "No pre-release found, falling back to latest stable." -ForegroundColor Yellow
            $targetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
        }
    } else {
        $targetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
    }

    $asset = $targetRelease.assets | Where-Object { $_.name -eq "Frontier.zip" } | Select-Object -First 1
    if ($null -eq $asset) { throw "Frontier.zip not found in the selected release." }

    Write-Host "Downloading Frontier ($($targetRelease.tag_name))..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$zip"

    Write-Host "Extracting files..." -ForegroundColor Gray
    Expand-Archive -Path "$zip" -DestinationPath "$destFull" -Force

    Write-Host "Configuring .gitignore..." -ForegroundColor Gray
    $gitignorePath = Join-Path "$destFull" ".gitignore"
    $gitignoreRules = ".frontier/`nback.bat`nfront.bat`nfrontier.bat"

    if (Test-Path $gitignorePath) {
        Add-Content -Path $gitignorePath -Value "`n$gitignoreRules" -Encoding utf8
    } else {
        Set-Content -Path $gitignorePath -Value $gitignoreRules -Encoding utf8
    }

    Remove-Item "$zip" -Force

    if (Get-Command "rustc" -ErrorAction SilentlyContinue) {
        Write-Host "Updating dependencies..." -ForegroundColor Gray
        Push-Location "$destFull"
        & ".\frontier.bat" update
        Pop-Location

        Write-Host "`nSuccess! Frontier installed." -ForegroundColor Green
        Write-Host "To start Frontier, run:" -ForegroundColor Gray
        Write-Host "cd '$dest'; .\frontier dev`n" -ForegroundColor DarkCyan
    } else {
        Write-Host "`nSuccess! Frontier installed." -ForegroundColor Green
        Write-Host "Missing requirements. See 'https://frontier-fw.dev/docs/?README.md#requirements' before proceeding." -ForegroundColor Yellow
    }
} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
}