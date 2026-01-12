$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 3072

$url = "https://github.com/frontier-org/frontier/archive/refs/heads/main.zip"
$tempDir = "C:\Temp"
if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
$zip = Join-Path $tempDir "frontier.zip"
$extractPath = Join-Path $tempDir "frontier_temp"

Write-Host "`n* Frontier Installer *`n" -ForegroundColor Cyan
$userInput = Read-Host "Project folder name (Leave empty for current folder)"
$dest = if($userInput){$userInput}else{(Get-Location).Path}

if(!(Test-Path "$dest")){ New-Item -ItemType Directory -Path "$dest" -Force | Out-Null }
$destFull = (Resolve-Path "$dest").Path

try {
    Write-Host "`nDownloading engine..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $url -OutFile "$zip"

    if (Test-Path "$extractPath") { Remove-Item -Recurse -Force "$extractPath" }
    Write-Host "Extracting files..." -ForegroundColor Gray
    Expand-Archive -Path "$zip" -DestinationPath "$extractPath" -Force
    $root = Get-ChildItem -Path "$extractPath" | Where-Object { $_.PSIsContainer } | Select-Object -First 1

    $items = @(".frontier", "back.bat", "front.bat", "frontier.bat")
    foreach ($i in $items) {
        $source = Join-Path $root.FullName $i
        if (Test-Path "$source") { 
            Copy-Item -Path "$source" -Destination "$destFull" -Recurse -Force 
        }
    }

    $legalFiles = @("LICENSE", "NOTICE")
    foreach ($f in $legalFiles) {
        $sourceLegal = Join-Path $root.FullName $f
        if (Test-Path "$sourceLegal") {
            $newName = $f + ".frontier"
            Copy-Item -Path "$sourceLegal" -Destination (Join-Path "$destFull" $newName) -Force
            Write-Host "Legal file added: $newName" -ForegroundColor DarkGray
        }
    }

    Write-Host "Creating .gitignore..." -ForegroundColor Gray
    $gitignorePath = Join-Path "$destFull" ".gitignore"
    $gitignoreRules = ".frontier/`nback.bat`nfront.bat`nfrontier.bat`nLICENSE.frontier`nNOTICE.frontier"

    if (Test-Path $gitignorePath) {
        Add-Content -Path $gitignorePath -Value "`n$gitignoreRules" -Encoding utf8
    } else {
        Set-Content -Path $gitignorePath -Value $gitignoreRules -Encoding utf8
    }

    Remove-Item "$zip" -Force
    Remove-Item -Recurse -Force "$extractPath"

    if (Get-Command "rustc" -ErrorAction SilentlyContinue) {
        Write-Host "Updating Frontier..." -ForegroundColor Gray
        Push-Location "$destFull"
        & ".\frontier.bat" update
        Pop-Location

        Write-Host "`nSuccess! Frontier installed." -ForegroundColor Green
        Write-Host "To start Frontier, run:" -ForegroundColor Gray
        Write-Host "cd '$dest'; .\frontier dev`n" -ForegroundColor DarkCyan
    } else {
        Write-Host "`nSuccess! Frontier installed." -ForegroundColor Green
        Write-Host "Please, to start Frontier, install Rust from 'https://rust-lang.org/tools/install/', and run:" -ForegroundColor Yellow
        Write-Host "cd '$destFull'; .\frontier update; .\frontier dev`n" -ForegroundColor DarkCyan
    }
} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
}