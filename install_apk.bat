@echo off
setlocal EnableDelayedExpansion
cls

:: Set window title (optional)
title APK Installer Tool

:: ------------------------------------------------------------
:: Retrieve ANSI escape character (ESC) for dynamic UI updates.
:: ------------------------------------------------------------
for /F "delims=" %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"

:: ------------------------------------------------------------
:: Define ANSI color variables (using not-too-bright colors)
:: ------------------------------------------------------------
set "RESET=%ESC%[0m"
set "INFO=%ESC%[36m"         & rem Cyan
set "SUCCESS=%ESC%[32m"      & rem Green
set "ERROR=%ESC%[31m"        & rem Red
set "HIGHLIGHT=%ESC%[33m"    & rem Yellow

:: ============================================================
::                   APK INSTALLER TOOL
:: ============================================================
echo %HIGHLIGHT%******************************************************%RESET%
echo %HIGHLIGHT%              APK INSTALLER TOOL                %RESET%
echo %HIGHLIGHT%******************************************************%RESET%
echo.

:: ------------------------------------------------------------
:: Check input parameter for APK file.
:: ------------------------------------------------------------
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

:: ------------------------------------------------------------
:: Set path to adb.exe (update if needed)
:: ------------------------------------------------------------
set "adb_path=D:\Env\platform-tools\adb.exe"
if not exist "%adb_path%" (
    echo %ERROR%[Error]%RESET% adb.exe not found at "%adb_path%". Please verify the path.
    pause
    exit /b
)

:: ------------------------------------------------------------
:: Check for connected Android device.
:: ------------------------------------------------------------
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

:: ------------------------------------------------------------
:: Retrieve device properties for friendly display.
:: ------------------------------------------------------------
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

:: ------------------------------------------------------------
:: Retrieve APK info using aapt.exe if available.
:: ------------------------------------------------------------
set "aapt_path=D:\Env\platform-tools\aapt.exe"
if exist "%aapt_path%" (
    for /f "tokens=1-6 delims=' " %%a in ('"%aapt_path%" dump badging "%apk_path%" ^| findstr "package:"') do (
        set "dummy=%%a"
        set "pkg=%%b"
        set "dummy2=%%c"
        set "vcode=%%d"
        set "dummy3=%%e"
        set "vname=%%f"
    )
    echo %HIGHLIGHT%APK Information:%RESET%
    echo    %HIGHLIGHT%Package Name%RESET% : %pkg%
    echo    %HIGHLIGHT%Version%RESET%      : %vname%
    echo.
) else (
    echo %INFO%[Notice]%RESET% aapt.exe not found at "%aapt_path%". Skipping APK detail extraction.
    echo.
    set "pkg="
    set "vname="
)

:: ------------------------------------------------------------
:: If APK package info is available, check if the package is already installed.
:: ------------------------------------------------------------
if defined pkg (
    "%adb_path%" -s %device% shell pm list packages | findstr /i "%pkg%" >nul 2>&1
    if %errorlevel%==0 (
        echo %HIGHLIGHT%[Override]%RESET% Package %pkg% is already installed.
        for /f "tokens=*" %%i in ('"%adb_path%" -s %device% shell dumpsys package %pkg% ^| findstr "versionName"') do (
             set "installed_version=%%i"
        )
        for /f "tokens=2 delims==" %%i in ("%installed_version%") do set "installed_version=%%i"
        echo    %HIGHLIGHT%Installed Version:%RESET% %installed_version%
        echo    %HIGHLIGHT%New APK Version:%RESET%   %vname%
    ) else (
        echo %INFO%Package %pkg% is not installed. Proceeding with fresh installation.%RESET%
    )
    echo.
) else (
    echo %INFO%Skipping package override check due to missing APK details.%RESET%
    echo.
)

:: ------------------------------------------------------------
:: Start APK installation and create temporary log file.
:: ------------------------------------------------------------
echo %INFO%Installing APK on device:%RESET% %friendlyDevice% (ID: %device%)...
set "log_file=%TEMP%\adb_install.log"
if exist "%log_file%" del "%log_file%"

:: Execute adb install with -r flag to replace/override if needed.
start "" /B cmd /c ""%adb_path%" -s %device% install -r "%apk_path%" > "%log_file%" 2>&1"

:: ------------------------------------------------------------
:: Spinner loop: display spinner animation while waiting for installation.
:: ------------------------------------------------------------
set "spinner=\|/-"
set /a index=0

:spinner_loop
    rem Check if installation succeeded or failed.
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
