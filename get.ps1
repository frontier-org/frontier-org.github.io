# Error handling and Secure Protocol
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 3072

# Paths
$url = "https://github.com/frontier-org/frontier/archive/refs/heads/main.zip"
$zip = "$env:TEMP\frontier.zip"
$temp = "$env:TEMP\frontier_temp"

# User Input
Write-Host "* Get Frontier *" -ForegroundColor Cyan
$input = Read-Host "Project folder name (Leave empty for current folder)"
$dest = if($input){$input}else{(Get-Location).Path}
if($input -and !(Test-Path $dest)){ New-Item -ItemType Directory -Path $dest | Out-Null }

try {
    # Download
    Write-Host "Downloading engine..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $url -OutFile $zip

    # Extract
    if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
    Write-Host "Extracting files..." -ForegroundColor Gray
    Expand-Archive -Path $zip -DestinationPath $temp
    $root = Get-ChildItem -Path $temp | Select-Object -First 1

    # Installation
    $items = @(".frontier", "back.bat", "front.bat", "frontier.bat")
    foreach ($i in $items) {
        $source = Join-Path $root.FullName $i
        if (Test-Path $source) { Copy-Item -Path $source -Destination $dest -Recurse -Force }
    }

    # Gitignore
    Write-Host "Creating .gitignore..." -ForegroundColor Gray
    ".frontier/`nback.bat`nfront.bat`nfrontier.bat" | Out-File -FilePath (Join-Path $dest ".gitignore") -Encoding utf8

    # Cleanup
    Remove-Item $zip -Force
    Remove-Item -Recurse -Force $temp

    Write-Host "`nSuccess! Frontier installed in: $dest" -ForegroundColor Green

} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
}