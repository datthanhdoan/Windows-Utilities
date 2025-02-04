@echo off
setlocal EnableDelayedExpansion
cls

:: ------------------------------------------------------------
:: Retrieve the ANSI escape character (ESC)
:: ------------------------------------------------------------
for /F "delims=" %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"

:: ------------------------------------------------------------
:: Check input parameter for APK file.
:: ------------------------------------------------------------
if "%~1"=="" (
    echo No APK file path provided.
    echo Usage: install_apk.bat "path\to\your.apk"
    pause
    exit /b
)
set "apk_path=%~1"
if not exist "%apk_path%" (
    echo APK file not found: "%apk_path%"
    pause
    exit /b
)

:: ------------------------------------------------------------
:: Set the path to adb.exe (update this if needed)
:: ------------------------------------------------------------
set "adb_path=D:\Env\platform-tools\adb.exe"
if not exist "%adb_path%" (
    echo adb.exe not found at "%adb_path%". Please check the path.
    pause
    exit /b
)

:: ------------------------------------------------------------
:: Check for connected Android device.
:: ------------------------------------------------------------
echo Checking for connected Android devices...
set "device="
for /f "skip=1 tokens=1,2" %%A in ('"%adb_path%" devices') do (
    if /I "%%B"=="device" (
         set "device=%%A"
         goto :device_found
    )
)
:device_found
if not defined device (
    echo No Android device found.
    echo Please connect a device and enable USB debugging.
    pause
    exit /b
)

:: ------------------------------------------------------------
:: Retrieve device properties for a friendly display.
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

echo Device found: %friendlyDevice% (ID: %device%)

:: ------------------------------------------------------------
:: Start APK installation and create a temporary log file.
:: ------------------------------------------------------------
echo Installing APK on device: %friendlyDevice% (ID: %device%)...
set "log_file=%TEMP%\adb_install.log"
if exist "%log_file%" del "%log_file%"

:: Run adb install in the background, redirecting output to the log file.
start "" /B cmd /c ""%adb_path%" -s %device% install -r "%apk_path%" > "%log_file%" 2>&1"

:: ------------------------------------------------------------
:: Spinner loop: display a spinner animation on a single line.
:: Also, check every loop if the device is still connected.
:: ------------------------------------------------------------
set "spinner=\|/-"
set /a index=0

:spinner_loop
    :: Check if the installation succeeded or failed by scanning the log file.
    findstr /C:"Success" "%log_file%" >nul 2>&1 && goto install_success
    findstr /C:"Failure" "%log_file%" >nul 2>&1 && goto install_failure

    :: Check if the device is still connected.
    "%adb_path%" -s %device% get-state >nul 2>&1
    if errorlevel 1 goto device_disconnected

    set /a index=(index+1) %% 4
    set "char=!spinner:~%index%,1!"
    <nul set /p ="%ESC%[2K%ESC%[1GInstalling... !char! (Device: %friendlyDevice%)"
    ping -n 1 -w 300 127.0.0.1 >nul
goto spinner_loop

:install_success
echo.
echo APK installed successfully on device: %friendlyDevice% (ID: %device%)!
goto end

:install_failure
echo.
echo APK installation failed on device: %friendlyDevice% (ID: %device%).
echo Error details:
type "%log_file%"
goto end

:device_disconnected
echo.
echo Device disconnected. Installation aborted.
goto end

:end
echo.
pause
exit /b
