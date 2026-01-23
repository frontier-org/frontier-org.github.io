# Copyright (c) 2026 The Frontier Framework Authors
# SPDX-License-Identifier: Apache-2.0 OR MIT

# Local: iex(gc -raw .\win\get.ps1)
# Remote: iex(irm https://frontier-fw.dev/win/get.ps1)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 3072

$version = "v0.1.0-alpha.6"

# --- Configurations ---
$repo = "frontier-org/frontier"
$tempDir = "C:\Temp"
$zip = Join-Path $tempDir "Frontier-Windows.zip"
$defaultUsePrerelease = $true

$deletPaths = ".frontier\
back.bat
front.bat
frontier.bat"

$gitignoreRules = "/.frontier/
/dist/
/back.bat
/front.bat
/frontier.bat"

function Cleanup-FrontierSession {
    $Global:v  = $null
    $Global:p  = $null
    $Global:pr = $null
    $Global:ni = $null
    $Global:nu = $null
    $Global:h  = $null
}

try {
    if ($h -eq '1') {
        Write-Host "`n* Frontier Installer Help ($version) *" -ForegroundColor Magenta

        Write-Host "`nAvailable Variables:"
        Write-Host "`$v     " -NoNewline -ForegroundColor Cyan
        Write-Host "Specific version tag (e.g., '0.1.0')." -ForegroundColor DarkGray
        Write-Host "`$p     " -NoNewline -ForegroundColor Cyan
        Write-Host "Target directory (e.g., 'MyProject' or '.')." -ForegroundColor DarkGray
        Write-Host "`$pr    " -NoNewline -ForegroundColor Cyan
        Write-Host "Boolean (1/0) to force/ignore pre-release." -ForegroundColor DarkGray
        Write-Host "`$ni    " -NoNewline -ForegroundColor Cyan
        Write-Host "Boolean (1) to skip '.gitignore' config." -ForegroundColor DarkGray
        Write-Host "`$nu    " -NoNewline -ForegroundColor Cyan
        Write-Host "Boolean (1) to skip '.\frontier update'." -ForegroundColor DarkGray
        Write-Host "`$h     " -NoNewline -ForegroundColor Cyan
        Write-Host "Boolean (1) to show this screen." -ForegroundColor DarkGray

        Write-Host "`nExample:"
        Write-Host "`$v='0.1.0'; `$p='Frontier'; `$pr=1; `$ni=1; `$nu=1; iex(irm https://frontier-fw.dev/win/get.ps1)" -ForegroundColor Cyan
        Write-Host "`$v='0.1.0'; `$p='.'; iex(irm https://frontier-fw.dev/win/v0.1.0-alpha.5/get.ps1)" -ForegroundColor Cyan

        Write-Host "`nSee more details in 'https://frontier-fw.dev/docs/?MANUAL.md#windows'.`n" -ForegroundColor Yellow
        return
    }

    $targetRelease = $null

    if ($v) {
        try {
            $targetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/v$v"
        } catch {
            Write-Host "Error: Version 'v$v' not found in repository." -ForegroundColor Red
            return
        }
    }
    Write-Host "`n* Frontier Installer ($version) *" -ForegroundColor Magenta

    Write-Host "`nFor Installer help, run in PowerShell:" -ForegroundColor DarkGray
    Write-Host "`$h=1; iex(irm https://frontier-fw.dev/win/get.ps1)`n" -ForegroundColor DarkCyan

    if ($p) {
        $dest = $p
    } else {
        $userInput = Read-Host "Project folder name (Leave empty for current folder)"
        $dest = if($userInput){$userInput}else{(Get-Location).Path}
    }

    if(!(Test-Path "$dest")){ New-Item -ItemType Directory -Path "$dest" -Force | Out-Null }
    $destFull = (Resolve-Path "$dest").Path
    if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }

    if ($null -eq $targetRelease) {
        Write-Host "Fetching release info..."
        
        if ($pr -eq '1' -or ($defaultUsePrerelease -and $pr -ne '0')) {
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases"
            $targetRelease = $releases | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
            if ($null -eq $targetRelease) {
                Write-Host "No pre-release found, falling back to latest stable." -ForegroundColor Yellow
                $targetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
            }
        } else {
            $targetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
        }
    }

    $asset = $targetRelease.assets | Where-Object { $_.name -eq "Frontier-Windows.zip" } | Select-Object -First 1
    if ($null -eq $asset) { throw "Frontier-Windows.zip not found in release ($($targetRelease.tag_name))." }

    Write-Host "Downloading Frontier ($($targetRelease.tag_name))..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$zip"

    Write-Host "Cleaning up existing files..."
    $deletPaths -split "`n" | ForEach-Object {
        $p = $_.Trim()
        if ($p) {
            $f = Join-Path "$destFull" $p
            if (Test-Path $f) { Remove-Item -Path $f -Recurse -Force }
        }
    }

    Write-Host "Extracting files..."
    Expand-Archive -Path "$zip" -DestinationPath "$destFull" -Force

    if (!($ni -eq '1')) {
        Write-Host "Configuring .gitignore..."
        $gi = Join-Path "$destFull" ".gitignore"
        $rules = $gitignoreRules -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        if (Test-Path $gi) {
            $cur = Get-Content $gi
            $new = @(); foreach ($r in $rules) { if ($cur -notcontains $r) { $new += $r } }
            if ($new.Count -gt 0) { Add-Content -Path $gi -Value ("`n" + ($new -join "`n")) -Encoding utf8 }
        } else {
            Set-Content -Path $gi -Value ($rules -join "`n") -Encoding utf8
        }
    }

    Remove-Item "$zip" -Force

    if (Get-Command "rustc" -ErrorAction SilentlyContinue) {
        if (!($nu -eq '1')) {
            Write-Host "Updating dependencies..."
            Push-Location "$destFull"
            & ".\frontier.bat" update
            Pop-Location
            Write-Host "`nSuccess! Frontier installed and updated." -ForegroundColor Green
        } else {
            Write-Host "`nSuccess! Frontier installed (Update skipped)." -ForegroundColor Green
        }
        Write-Host "To start Frontier, run: cd '$dest'; .\frontier dev`n" -ForegroundColor Cyan
    } else {
        Write-Host "`nSuccess! Frontier installed (Update skipped)." -ForegroundColor Green

        Write-Host "Missing Rust. See more details in 'https://frontier-fw.dev/docs/?MANUAL.md#windows'.`n" -ForegroundColor Yellow
    }

} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Cleanup-FrontierSession
}