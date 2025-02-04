@echo off
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

rem Configuration - Update these paths according to your environment:
set "adb_path=D:\Env\platform-tools\adb.exe"
set "aapt_path=D:\UnityEditor\2022.3.52f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\build-tools\35.0.0\aapt.exe"
set "apk_path=path\to\your.apk"

setlocal EnableDelayedExpansion
cls

:: Set window title
title APK Installer Tool

:: Retrieve ANSI escape character for dynamic UI updates.
for /F "delims=" %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"

:: Define ANSI color variables
set "RESET=%ESC%[0m"
set "INFO=%ESC%[36m"
set "SUCCESS=%ESC%[32m"
set "ERROR=%ESC%[31m"
set "HIGHLIGHT=%ESC%[33m"

:: Header
echo %HIGHLIGHT%======================================================%RESET%
echo %HIGHLIGHT%  APK INSTALLER TOOL  %RESET%
echo %HIGHLIGHT%======================================================%RESET%
echo.

:: Check input parameter for APK file.
if "%~1"=="" (
  echo %ERROR%[Error]%RESET% No APK file path provided.
  echo %INFO%Usage:%RESET% install_apk.bat "path\to\your.apk"
  pause
  exit /b
)
set "apk_path=%~1"
if not exist "%apk_path%" (
  echo %ERROR%[Error]%RESET% APK file not found: "%apk_path%"
  pause
  exit /b
)

:: Set path to adb.exe (update if needed)
set "adb_path=D:\Env\platform-tools\adb.exe"
if not exist "%adb_path%" (
  echo %ERROR%[Error]%RESET% adb.exe not found at "%adb_path%". Please verify the path.
  pause
  exit /b
)

:: Check for connected Android device.
echo %INFO%Checking for connected Android devices...%RESET%
set "device="
for /f "skip=1 tokens=1,2" %%A in ('"%adb_path%" devices') do (
  if /I "%%B"=="device" (
    set "device=%%A"
    goto :device_found
  )
)
:device_found
if not defined device (
  echo %ERROR%[Error]%RESET% No Android device found.
  echo %INFO%Please connect a device and enable USB debugging.%RESET%
  pause
  exit /b
)

:: Retrieve device properties.
for /f "delims=" %%b in ('"%adb_path%" -s %device% shell getprop ro.product.manufacturer') do set "manufacturer=%%b"
for /f "delims=" %%c in ('"%adb_path%" -s %device% shell getprop ro.product.model') do set "model=%%c"
for /f "delims=" %%d in ('"%adb_path%" -s %device% shell getprop ro.config.marketing_name') do set "marketingName=%%d"
if "%manufacturer%"=="" set "manufacturer=UnknownManufacturer"
if "%model%"=="" set "model=UnknownModel"
if not "%marketingName%"=="" (
  set "friendlyDevice=%marketingName%"
  ) else (
  set "friendlyDevice=%manufacturer% %model%"
)

echo.
echo %HIGHLIGHT%Device found:%RESET% %friendlyDevice% (ID: %device%)
echo.

:: Retrieve APK info using aapt.exe if available.
set "aapt_path=D:\UnityEditor\2022.3.52f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\build-tools\35.0.0\aapt.exe"

:: Ensure previous temporary files are deleted.
if exist "%TEMP%\temp_apk_file.tmp" del /F /Q "%TEMP%\temp_apk_file.tmp"
if exist "%TEMP%\aapt_debug.log" del /F /Q "%TEMP%\aapt_debug.log"

set "temp_apk=%TEMP%\temp_apk_file.tmp"
copy /Y "%apk_path%" "%temp_apk%" >nul
if not exist "%temp_apk%" (
  echo %ERROR%[Error]%RESET% Failed to create temporary file: "%temp_apk%"
  pause
  exit /b
)

:: Dump aapt.exe output into a debug file.
set "debug_file=%TEMP%\aapt_debug.log"
"%aapt_path%" dump badging "%temp_apk%" > "%debug_file%" 2>&1

:: Read the debug file to find the line containing "package:".
set "line="
for /f "usebackq tokens=*" %%L in ("%debug_file%") do (
  echo %%L | findstr /c:"package:" >nul
  if not errorlevel 1 (
    set "line=%%L"
    goto :gotLine
  )
)
:gotLine

:: Delete temporary files.
del /F /Q "%temp_apk%"
del /F /Q "%debug_file%"

:: If no line was found, report error.
if not defined line (
  echo %ERROR%[Error]%RESET% Failed to extract package info from aapt output.
  goto afterExtract
)

:: Process the captured line.
:: Expected format:
:: package: name='com.bus.chaos.parking.jam' versionCode='33' versionName='1.0.7.2' ...
for /f "tokens=3,5,7 delims=' " %%a in ("!line!") do (
  set "pkg=%%a"
  set "vcode=%%b"
  set "vname=%%c"
)

:afterExtract

:: Display APK Information.
echo %HIGHLIGHT%------------------------------------------------------%RESET%
echo %HIGHLIGHT%  APK INFORMATION  %RESET%
echo %HIGHLIGHT%------------------------------------------------------%RESET%
echo.
echo %INFO%Package Name:  %RESET%  !pkg!
echo %INFO%APK Version:  %RESET%  !vname!
echo %INFO%Version Code:  %RESET%  !vcode!
echo.

:: Check if package is already installed.
if defined pkg (
  "%adb_path%" -s %device% shell pm list packages --user 0 | findstr /i "!pkg!" >nul 2>&1
  if !errorlevel! == 0 (
    echo %HIGHLIGHT%------------------------------------------------------%RESET%
    echo %HIGHLIGHT%  [Override] Package already installed  %RESET%
    
    :: Dump package info from device.
    "%adb_path%" -s !device! shell dumpsys package !pkg! > "%TEMP%\dumpsys_output.txt"
    
    :: Parse versionName
    for /f "tokens=2 delims==' " %%A in ('findstr /i "versionName" "%TEMP%\dumpsys_output.txt"') do set "installed_version=%%A"
    :: Parse versionCode
    for /f "tokens=2 delims== " %%B in ('findstr /i "versionCode" "%TEMP%\dumpsys_output.txt"') do set "installed_vcode=%%B"
    del /F /Q "%TEMP%\dumpsys_output.txt"
    
    set "PAD20=                    "
    set "installed_version_padded=!installed_version!!PAD20!"
    set "installed_version_padded=!installed_version_padded:~0,20!"
    set "vname_padded=!vname!!PAD20!"
    set "vname_padded=!vname_padded:~0,20!"
    set "installed_vcode_padded=!installed_vcode!!PAD20!"
    set "installed_vcode_padded=!installed_vcode_padded:~0,20!"
    set "vcode_padded=!vcode!!PAD20!"
    set "vcode_padded=!vcode_padded:~0,20!"
    
    echo %INFO%^| Field          ^| Existing Value      ^| New Value           ^|%RESET%
    echo %INFO%+---------------+--------------------+--------------------+%RESET%
    echo %INFO%^| Version Name  ^| !installed_version_padded!  ^| !vname_padded!  ^|%RESET%
    echo %INFO%^| Version Code  ^| !installed_vcode_padded!  ^| !vcode_padded!  ^|%RESET%
    echo %INFO%+---------------+--------------------+--------------------+%RESET%
  ) else (
    echo %INFO%Package !pkg! is not installed. Proceeding with fresh installation.%RESET%
  )
  echo.
) else (
  echo %INFO%Skipping package override check due to missing APK details.%RESET%
  echo.
)

:: Install APK.
echo %INFO%Installing APK on device:%RESET% %friendlyDevice% (ID: %device%)...
set "log_file=%TEMP%\adb_install.log"
if exist "%log_file%" del /F /Q "%log_file%"
start "" /B cmd /c "%adb_path% -s %device% install -r "%apk_path%" > "%log_file%" 2>&1"

:: Spinner loop.
set "spinner=\|/-"
set /a index=0

:spinner_loop
rem Check installation status.
findstr /C:"Success" "%log_file%" >nul 2>&1 && goto install_success
findstr /C:"Failure" "%log_file%" >nul 2>&1 && goto install_failure

rem Check if device is still connected.
"%adb_path%" -s %device% get-state >nul 2>&1
if errorlevel 1 goto device_disconnected

set /a index=(index+1) %% 4
set "char=!spinner:~%index%,1!"
<nul set /p ="%ESC%[2K%ESC%[1G%INFO%Installing... !char! (Device: %friendlyDevice%)%RESET%"
ping -n 1 -w 300 127.0.0.1 >nul
goto spinner_loop

:install_success
echo.
echo %SUCCESS%[Success]%RESET% APK installed successfully on device: %friendlyDevice% (ID: %device%)!
goto end

:install_failure
echo.
echo %ERROR%[Error]%RESET% APK installation failed on device: %friendlyDevice% (ID: %device%).
echo %INFO%Log details:%RESET%
type "%log_file%"
goto end

:device_disconnected
echo.
echo %ERROR%[Error]%RESET% Device disconnected. Installation aborted.
goto end

:end
echo.
pause
exit /b
