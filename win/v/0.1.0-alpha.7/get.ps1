# Copyright (c) 2026 The Frontier Framework Authors
# SPDX-License-Identifier: Apache-2.0 OR MIT

param(
    [Alias('v')][string]$Version,
    [Alias('p')][string]$Path,
    [Alias('pr')][switch]$PreRelease,
    [Alias('ni')][switch]$NoGitignore,
    [Alias('nu')][switch]$NoUpdate,
    [Alias('h')][switch]$Help
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = 3072

$scriptVersion = "v0.1.0-alpha.7"

# --- Configurations ---

$PreRelease = $true

$Repo = "frontier-org/frontier"
$TempDir = "C:\Temp"
$Zip = Join-Path $TempDir "Frontier-Windows.zip"
$DeletPaths = ".frontier\", "back.bat", "front.bat", "frontier.bat"
$GitignoreRules = "/.frontier/", "/dist/", "/back.bat", "/front.bat", "/frontier.bat"

if ($Help) {
    Write-Host "`n* Frontier Installer Help ($ScriptVersion) *" -ForegroundColor Magenta

    Write-Host "`nAvailable Arguments:"
    Write-Host "  -Version <version>, -v <version>  " -NoNewline -ForegroundColor Cyan
    Write-Host "Specific version tag (e.g., '0.1.0')" -ForegroundColor DarkGray
    Write-Host "  -Path <path>, -p <path>           " -NoNewline -ForegroundColor Cyan
    Write-Host "Target directory (e.g., 'My App' or '.')" -ForegroundColor DarkGray
    Write-Host "  -PreRelease, -pr                  " -NoNewline -ForegroundColor Cyan
    Write-Host "Force use of pre-release versions" -ForegroundColor DarkGray
    Write-Host "  -NoGitignore, -ni                 " -NoNewline -ForegroundColor Cyan
    Write-Host "Skip '.gitignore' configuration" -ForegroundColor DarkGray
    Write-Host "  -NoUpdate, -nu                    " -NoNewline -ForegroundColor Cyan
    Write-Host "Skip '.\frontier update'" -ForegroundColor DarkGray
    Write-Host "  -Help, -h                         " -NoNewline -ForegroundColor Cyan
    Write-Host "Show this help screen" -ForegroundColor DarkGray

    Write-Host "`nExample:"
    Write-Host "  iex `"`& { `$(irm 'https://frontier-fw.dev/win/get.ps1') } -Path 'My App' -NoGitignore`"" -ForegroundColor Cyan
    return
}

try {

    if ($Version) {
        try {
            $TargetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/v$Version"
        } catch {
            Write-Host "Error: Version 'v$Version' not found." -ForegroundColor Red
            return
        }
    }

    Write-Host "`n* Frontier Installer ($ScriptVersion) *" -ForegroundColor Magenta
    Write-Host "`nFor help, run: " -NoNewline  -ForegroundColor DarkGray
    Write-Host "iex `"& { `$(irm 'https://frontier-fw.dev/win/get.ps1') } -Help`"`n" -ForegroundColor Cyan

    # Path Logic
    $Dest = if ($Path) { $Path } else { 
        $UserInput = Read-Host "Project folder name (Leave empty for current folder)"
        if ($UserInput) { $UserInput } else { (Get-Location).Path }
    }

    if (!(Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    $DestFull = (Resolve-Path $Dest).Path
    if (!(Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }

    # Release Selection
    if ($null -eq $TargetRelease) {
        Write-Host "Fetching release info..."
        if ($PreRelease) {
            $Releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases"
            $TargetRelease = $Releases | Where-Object { $_.PreRelease -eq $true } | Select-Object -First 1
        }
        
        if ($null -eq $TargetRelease) {
            if ($PreRelease) { Write-Host "No pre-release found, falling back to stable." -ForegroundColor Yellow }
            $TargetRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
        }
    }

    $Asset = $TargetRelease.assets | Where-Object { $_.name -eq "Frontier-Windows.zip" } | Select-Object -First 1
    if ($null -eq $Asset) { throw "Frontier-Windows.zip not found in release $($TargetRelease.tag_name)." }

    # Download and Clean
    Write-Host "Downloading Frontier ($($TargetRelease.tag_name))..."
    Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $Zip

    Write-Host "Cleaning existing files..."
    foreach ($Item in $DeletPaths) {
        $f = Join-Path $DestFull $Item.Trim()
        if (Test-Path $f) { Remove-Item -Path $f -Recurse -Force }
    }

    Write-Host "Extracting files..."
    Expand-Archive -Path $Zip -DestinationPath $DestFull -Force

    # Gitignore Logic
    if (!$NoGitignore) {
        Write-Host "Configuring .gitignore..."
        $Gitignore = Join-Path $DestFull ".gitignore"
        $Rules = $GitignoreRules | ForEach-Object { $_.Trim() }
        if (Test-Path $Gitignore) {
            $Cur = Get-Content $Gitignore
            $New = $Rules | Where-Object { $Cur -notcontains $_ }
            if ($New) { Add-Content -Path $Gitignore -Value ("`n" + ($New -join "`n")) -Encoding utf8 }
        } else {
            Set-Content -Path $Gitignore -Value ($Rules -join "`n") -Encoding utf8
        }
    }

    Remove-Item $Zip -Force

    # Execution
    $HasRust = Get-Command "rustc" -ErrorAction SilentlyContinue
    if ($HasRust -and !$NoUpdate) {
        Write-Host "Updating dependencies..."
        Push-Location $DestFull
        try { & ".\frontier.bat" update } finally { Pop-Location }
        Write-Host "`nSuccess! Frontier installed and updated." -ForegroundColor Green
    } else {
        $Reason = if (!$HasRust) { "(Missing Rust)" } else { "(Update skipped)" }
        Write-Host "`nSuccess! Frontier installed $Reason." -ForegroundColor Green
    }
    
    Write-Host "To start: " -NoNewline -ForegroundColor DarkGray
    Write-Host "cd '$Dest'; .\frontier dev`n" -ForegroundColor Cyan

} catch {
    Write-Host "`nTerminal Error: $($_.Exception.Message)" -ForegroundColor Red
}
