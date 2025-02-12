# Simple APK Installer
param([string]$ApkPath)

if (-not $ApkPath) {
    Write-Host "Usage: apk-install.ps1 -ApkPath path\to\your.apk"
    exit 1
}

# Find ADB
$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adbPath)) {
    $adbPath = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source
}

if (-not $adbPath) {
    Write-Host "Error: adb.exe not found"
    exit 1
}

# Check APK exists
if (-not (Test-Path $ApkPath)) {
    Write-Host "Error: APK file not found: $ApkPath"
    exit 1
}

# Start ADB server
& $adbPath start-server

# Get device
$device = (& $adbPath devices) -match "device$" | ForEach-Object { ($_ -split "\s+")[0] } | Select-Object -First 1

if (-not $device) {
    Write-Host "Error: No device found"
    exit 1
}

# Install APK
Write-Host "Installing APK..."
& $adbPath -s $device install -r $ApkPath 