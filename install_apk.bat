@echo off
if "%1"=="" (
    echo Please provide the path to the APK file.
    echo Usage: install_apk.bat path_to_your_apk.apk
    goto end
)
set apk_path=%1
echo Installing APK from %apk_path%...
X:\Home\Documents\platform-tools/adb.exe install -r %apk_path%
if %errorlevel%==0 (
    echo APK installed successfully!
) else (
    echo Failed to install APK. Check for errors.
)
:end
pause
