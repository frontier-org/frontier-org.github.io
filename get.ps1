# Copyright (c) 2026 The Frontier Framework Authors
# SPDX-License-Identifier: Apache-2.0 OR MIT

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 3072

# --- Configurations ---
$repo = "frontier-org/frontier"
$tempDir = "C:\Temp"
$zip = Join-Path $tempDir "Frontier-Windows.zip"
$defaultUsePrerelease = $true

$deletPaths = ".frontier/
back.bat
front.bat
frontier.bat"

$gitignoreRules = ".frontier/
dist/
back.bat
front.bat
frontier.bat"

function Cleanup-FrontierSession {
    $Global:v  = $null
    $Global:p  = $null
    $Global:pr = $null
    $Global:ni = $null
    $Global:nu = $null
    $Global:h  = $null
}

try {
    if ($h) {
        Write-Host "`n* Usage for Frontier Installer *`n" -ForegroundColor Cyan
        Write-Host "Set the variables before running the install command."
        Write-Host "`nSyntax Example:" -ForegroundColor Gray
        Write-Host "  `$v='0.1.0'; `$p='.'; `$nu=`$true; iex(irm https://frontier-fw.dev/get.ps1)"
        Write-Host "`nAvailable Variables:" -ForegroundColor Gray
        Write-Host "  `$v     Specific version tag (e.g., '0.1.0')"
        Write-Host "  `$p     Target directory (e.g., 'MyProject' or '.')"
        Write-Host "  `$pr    Boolean (`$true/`$false) to force pre-release"
        Write-Host "  `$ni    Boolean (`$true) to skip .gitignore config"
        Write-Host "  `$nu    Boolean (`$true) to skip 'frontier update'"
        Write-Host "  `$h     Boolean (`$true) to show this screen`n"
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

    Write-Host "`n* Frontier Installer *`n" -ForegroundColor Cyan
    Write-Host "For Installer help, run in PowerShell:" -ForegroundColor Gray
    Write-Host "`$h=`$true; iex(irm https://frontier-fw.dev/get.ps1)`n" -ForegroundColor Gray

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
        Write-Host "Fetching release info..." -ForegroundColor Gray
        $usePR = if($pr -ne $null){ $pr } else { $defaultUsePrerelease }
        
        if ($usePR) {
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

    Write-Host "Downloading Frontier ($($targetRelease.tag_name))..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$zip"

    Write-Host "Cleaning up existing files..." -ForegroundColor Gray
    $deletPaths -split "`n" | ForEach-Object {
        $p = $_.Trim()
        if ($p) {
            $f = Join-Path "$destFull" $p
            if (Test-Path $f) { Remove-Item -Path $f -Recurse -Force }
        }
    }

    Write-Host "Extracting files..." -ForegroundColor Gray
    Expand-Archive -Path "$zip" -DestinationPath "$destFull" -Force

    if (-not $ni) {
        Write-Host "Configuring .gitignore..." -ForegroundColor Gray
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
        if (-not $nu) {
            Write-Host "Updating dependencies..." -ForegroundColor Gray
            Push-Location "$destFull"
            & ".\frontier.bat" update
            Pop-Location
            Write-Host "`nSuccess! Frontier installed and updated." -ForegroundColor Green
        } else {
            Write-Host "`nSuccess! Frontier installed (Update skipped)." -ForegroundColor Green
        }
        Write-Host "To start Frontier, run: cd '$dest'; .\frontier dev`n" -ForegroundColor DarkCyan
    } else {
        Write-Host "`nSuccess! Frontier installed." -ForegroundColor Green
        Write-Host "Missing requirements (Rust). See 'https://frontier-fw.dev/docs/?README.md#requirements'." -ForegroundColor Yellow
    }

} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Cleanup-FrontierSession
}