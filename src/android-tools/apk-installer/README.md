# APK Installer Tool

A utility tool for quickly and conveniently installing APK files to Android devices via USB.

## Prerequisites

### 1. ADB (Android Debug Bridge) - Required

- Download and install [Platform Tools](https://developer.android.com/tools/releases/platform-tools)
- ADB is used for device connection and APK installation

### 2. AAPT (Android Asset Packaging Tool) - Optional

- Can be downloaded through SDK Manager > Build Tools
- Used for extracting APK information
- Without AAPT, some APK information display features will be limited

## Initial Configuration

1. Open `install_apk.bat` in a text editor
2. Update the paths for the following variables:

```powershell
set "adb_path=D:\Env\platform-tools\adb.exe"
set "aapt_path=D:\UnityEditor\2022.3.52f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\build-tools\35.0.0\aapt.exe"
```

## Usage Instructions

### Android Device Setup

1. Connect your Android device to your computer via USB
2. Enable "USB Debugging" in Developer Options
3. Accept the USB debugging authorization prompt on your device when asked

### Installing APKs

> Ensure your Android device is authorized for USB debugging
> There are two ways to use the tool:

#### Method 1: Set as Default APK Handler

1. Right-click any APK file
2. Select "Open with" > "Choose another app"
3. Click "More apps" > "Look for another app on this PC"
4. Browse and select `install_apk.bat`
5. Check "Always use this app to open .apk files" (optional)

After setup, simply double-click any APK file to install automatically.

#### Method 2: Run Directly from Command Line

```powershell
install_apk.bat "path\to\your\file.apk"
```

## Features

- Automatic Android device detection
- Display detailed device information
- Show APK information (if AAPT is available)
- Check and display installed version information (if exists)
- Installation progress with animation
- Installation result notification

## Troubleshooting

- Ensure ADB and AAPT paths are correctly updated in the script
- Verify USB connection and Debug mode is enabled
- Confirm USB debugging authorization on the device
