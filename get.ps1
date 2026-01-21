# Copyright (c) 2026 The Frontier Framework Authors
# SPDX-License-Identifier: Apache-2.0 OR MIT

<#
.SYNOPSIS
    Frontier Framework Installer.
.DESCRIPTION
    Downloads, extracts, and configures the Frontier Framework environment.
    Supports Global Variables for remote execution: $Tag, $Path, $PreRelease, $NoGitignore, $NoUpdate.
.PARAMETER Help
    Shows this help message.
.PARAMETER Path
    Target directory for installation (e.g., 'MyProject' or '.'). Skips prompt.
.PARAMETER Tag
    Specify a specific version tag to download (e.g., v0.1.0).
.PARAMETER PreRelease
    Forces the installer to look for the latest pre-release version.
.PARAMETER NoGitignore
    Skips any modifications or creation of the '.gitignore' file.
.PARAMETER NoUpdate
    Prevents the script from running '.\frontier.bat update' after installation.
#>

param(
    [switch]$Help,
    [string]$Path,
    [string]$Tag,
    [switch]$PreRelease,
    [switch]$NoGitignore,
    [switch]$NoUpdate
)

# --- Fallback for Remote Execution (Variables) ---
if (-not $PSBoundParameters.ContainsKey('Tag') -and $Global:Tag) { $Tag = $Global:Tag }
if (-not $PSBoundParameters.ContainsKey('Path') -and $Global:Path) { $Path = $Global:Path }
if (-not $PSBoundParameters.ContainsKey('PreRelease') -and $Global:PreRelease) { $PreRelease = $Global:PreRelease }
if (-not $PSBoundParameters.ContainsKey('NoGitignore') -and $Global:NoGitignore) { $NoGitignore = $Global:NoGitignore }
if (-not $PSBoundParameters.ContainsKey('NoUpdate') -and $Global:NoUpdate) { $NoUpdate = $Global:NoUpdate }

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 3072

$DefaultUsePrerelease = $true
$repo = "frontier-org/frontier"
$tempDir = "C:\Temp"
$zip = Join-Path $tempDir "Frontier-Windows.zip"

$deletPaths = ".frontier/
back.bat
front.bat
frontier.bat"

$gitignoreRules = ".frontier/
dist/
back.bat
front.bat
frontier.bat"

if ($Help -or $args) {
    if ($args) { Write-Host "`nError: Invalid argument(s) detected: $args" -ForegroundColor Red }
    $helpData = Get-Help $PSCommandPath
    Write-Host "`nUsage for $($helpData.Name):" -ForegroundColor Cyan
    Write-Host $helpData.Synopsis
    Write-Host "`nSyntax:" -ForegroundColor Gray
    Write-Host ($helpData.syntax | Out-String).Trim()
    Write-Host "`nParameters:" -ForegroundColor Gray
    $helpData.parameters.parameter | ForEach-Object {
        $desc = if ($_.description) { $_.description[0].Text } else { "No description available." }
        Write-Host "-$($_.name.PadRight(12)) $desc"
    }
    Write-Host ""
    exit
}

try {
    $targetRelease = $null

    if ($Tag) {
        Write-Host "Verifying tag '$Tag'..." -ForegroundColor Gray
        try {
            $targetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/$Tag"
        } catch {
            Write-Host "Error: The version tag '$Tag' does not exist in the repository." -ForegroundColor Red
            exit
        }
    }

    if ($Path) {
        $dest = $Path
    } else {
        Write-Host "`n* Frontier Installer *`n" -ForegroundColor Cyan
        $userInput = Read-Host "Project folder name (Leave empty for current folder)"
        $dest = if($userInput){$userInput}else{(Get-Location).Path}
    }

    if(!(Test-Path "$dest")){ New-Item -ItemType Directory -Path "$dest" -Force | Out-Null }
    $destFull = (Resolve-Path "$dest").Path
    if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }

    if ($null -eq $targetRelease) {
        Write-Host "Fetching release info..." -ForegroundColor Gray
        if ($PreRelease -or $DefaultUsePrerelease) {
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

    if (-not $NoGitignore) {
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
        if (-not $NoUpdate) {
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
}
