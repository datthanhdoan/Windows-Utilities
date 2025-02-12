# APK Installer Tool
param(
    [Parameter(Mandatory=$true)]
    [string]$ApkPath
)

function Find-Adb {
    $adbPath = $null
    
    # Check common locations
    $commonPaths = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:PROGRAMFILES\Android\platform-tools\adb.exe",
        "$env:PROGRAMFILES(x86)\Android\platform-tools\adb.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Try to find in PATH
    try {
        $adbPath = (Get-Command adb.exe -ErrorAction Stop).Source
        return $adbPath
    }
    catch {
        return $null
    }
}

function Install-Apk {
    param(
        [string]$AdbPath,
        [string]$ApkPath,
        [string]$DeviceId
    )
    
    $process = Start-Process -FilePath $AdbPath -ArgumentList "-s", $DeviceId, "install", "-r", $ApkPath -NoNewWindow -Wait -PassThru
    return $process.ExitCode -eq 0
}

# Verify APK file exists
if (-not (Test-Path $ApkPath)) {
    Write-Host "[Error] APK file not found: $ApkPath" -ForegroundColor Red
    exit 1
}

# Find ADB
$adbPath = Find-Adb
if (-not $adbPath) {
    Write-Host "[Error] adb.exe not found. Please install Android SDK Platform Tools." -ForegroundColor Red
    Write-Host "You can download it from: https://developer.android.com/tools/releases/platform-tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "[Info] Using ADB from: $adbPath"

# Start ADB server
Start-Process -FilePath $adbPath -ArgumentList "start-server" -NoNewWindow -Wait

# Get connected devices
$devices = & $adbPath devices | Select-Object -Skip 1 | Where-Object { $_ -match '^\S+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }

if (-not $devices) {
    Write-Host "[Error] No Android device found. Please connect a device and enable USB debugging." -ForegroundColor Red
    exit 1
}

$device = $devices[0]
$model = & $adbPath -s $device shell getprop ro.product.model
Write-Host "[Info] Found device: $model (ID: $device)"

# Install APK
Write-Host "[Info] Installing APK..."
if (Install-Apk -AdbPath $adbPath -ApkPath $ApkPath -DeviceId $device) {
    Write-Host "[Success] APK installed successfully." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "[Error] APK installation failed." -ForegroundColor Red
    exit 1
} 