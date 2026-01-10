# Error handling and Secure Protocol
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 3072

# Paths
$url = "https://github.com/frontier-org/frontier/archive/refs/heads/main.zip"
$zip = "$env:TEMP\frontier.zip"
$temp = "$env:TEMP\frontier_temp"

# User Input
Write-Host "`n* Frontier Installer *`n" -ForegroundColor Cyan
$inputDir = Read-Host "Project folder name (Leave empty for current folder)"
$dest = if($inputDir){$inputDir}else{(Get-Location).Path}

# Garante que a pasta de destino existe
if($inputDir -and !(Test-Path "$dest")){ 
    New-Item -ItemType Directory -Path "$dest" -Force | Out-Null 
}

try {
    # Download
    Write-Host "`nDownloading engine..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $url -OutFile "$zip"

    # Limpeza da pasta temporária antes de extrair
    if (Test-Path "$temp") { Remove-Item -Recurse -Force "$temp" }
    
    # Extract
    Write-Host "Extracting files..." -ForegroundColor Gray
    Expand-Archive -Path "$zip" -DestinationPath "$temp" -Force

    # Identifica a pasta raiz extraída (ex: frontier-main)
    $extractedFolder = Get-ChildItem -Path "$temp" | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    
    if ($null -eq $extractedFolder) {
        throw "Não foi possível encontrar a pasta extraída em $temp"
    }

    # Installation
    $items = @(".frontier", "back.bat", "front.bat", "frontier.bat")
    foreach ($i in $items) {
        $source = Join-Path $extractedFolder.FullName $i
        if (Test-Path "$source") { 
            Copy-Item -Path "$source" -Destination "$dest" -Recurse -Force 
            Write-Host "Copied: $i" -ForegroundColor DarkGray
        }
    }

    # Gitignore
    Write-Host "Creating .gitignore..." -ForegroundColor Gray
    ".frontier/`nback.bat`nfront.bat`nfrontier.bat" | Out-File -FilePath (Join-Path "$dest" ".gitignore") -Encoding utf8 -Force

    # Cleanup
    Remove-Item "$zip" -Force
    Remove-Item -Recurse -Force "$temp"

    # Check if Rust is installed
    if (Get-Command "rustc" -ErrorAction SilentlyContinue) {
        Write-Host "Updating Frontier..." -ForegroundColor Gray
        Push-Location "$dest"
        .\frontier update
        Pop-Location

        Write-Host "`nSuccess! Frontier installed." -ForegroundColor Green
        Write-Host "To start Frontier, run:" -ForegroundColor Gray
        Write-Host "cd '$dest'; .\frontier dev`n" -ForegroundColor DarkCyan
    } else {
        Write-Host "`nSuccess! Frontier installed." -ForegroundColor Green
        Write-Host "Please, to start Frontier, install Rust from 'https://rust-lang.org/tools/install/', and run:" -ForegroundColor Yellow

        $fullPath = (Resolve-Path "$dest").Path
        Write-Host "cd '$fullPath'; .\frontier update; .\frontier dev`n" -ForegroundColor DarkCyan
    }
} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
}