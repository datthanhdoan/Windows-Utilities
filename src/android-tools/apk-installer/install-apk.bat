@echo off
setlocal

rem =========================================================
rem APK INSTALLER TOOL
rem
rem Requirements:
rem 1. adb must be installed (mandatory)
rem    - Used for device connection and APK installation
rem 2. aapt is optional
rem    - Used for extracting APK information
rem    - If not available, some features will be limited
rem 3. Android device must be:
rem    - Connected via USB
rem    - USB debugging enabled
rem    - Authorized on the device
rem =========================================================

rem Configuration - Default paths for Android SDK tools:
set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "adb_path=%ANDROID_HOME%\platform-tools\adb.exe"
set "aapt_path=%ANDROID_HOME%\build-tools\33.0.0\aapt.exe"
set "apk_path="

echo [Info] Starting APK installation...
echo [Info] Checking prerequisites...

rem Check if APK path is provided
if "%~1"=="" (
    echo [Error] No APK file path provided.
    echo Usage: %~nx0 "path\to\your.apk"
    exit /b 1
)

rem Verify APK file exists
if not exist "%~1" (
    echo [Error] APK file not found: "%~1"
    exit /b 1
)

rem Try to find adb in common locations
set "adb_exe="
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "adb_exe=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
) else (
    for /f "delims=" %%i in ('where adb.exe 2^>nul') do (
        set "adb_exe=%%i"
        goto :found_adb
    )
    echo [Error] adb.exe not found. Please install Android SDK Platform Tools.
    exit /b 1
)
:found_adb

rem Start ADB server
"%adb_exe%" start-server

rem Check for connected devices
for /f "tokens=1" %%a in ('"%adb_exe%" devices ^| findstr /R /C:".*device$"') do (
    set "device=%%a"
    goto :install_apk
)

echo [Error] No Android device found. Please connect a device and enable USB debugging.
exit /b 1

:install_apk
echo [Info] Installing APK...
"%adb_exe%" -s %device% install -r "%~1"
if errorlevel 1 (
    echo [Error] Installation failed.
    exit /b 1
) else (
    echo [Success] APK installed successfully.
)

exit /b 0
