@echo off
echo ================================
echo Firebase Analytics Debug Mode
echo ================================
echo.
echo This script enables Firebase Analytics Debug Mode for your app.
echo.

echo Checking for connected devices...
flutter devices

echo.
echo Attempting to enable debug mode...
echo Running: adb shell setprop debug.firebase.analytics.app com.example.license_prep_app
echo.

REM Try to find adb in common locations
set "ADB_PATH="
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
) else if exist "%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_PATH=%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe"
) else (
    echo Trying to use adb from PATH...
    adb shell setprop debug.firebase.analytics.app com.example.license_prep_app
    if %errorlevel% == 0 (
        echo SUCCESS: Debug mode enabled!
        goto :verify
    ) else (
        echo ERROR: adb not found in PATH
        goto :manual
    )
)

if defined ADB_PATH (
    echo Using adb from: %ADB_PATH%
    "%ADB_PATH%" shell setprop debug.firebase.analytics.app com.example.license_prep_app
    if %errorlevel% == 0 (
        echo SUCCESS: Debug mode enabled!
        goto :verify
    ) else (
        echo ERROR: Failed to enable debug mode
        goto :manual
    )
) else (
    goto :manual
)

:verify
echo.
echo Verifying debug mode is enabled...
if defined ADB_PATH (
    "%ADB_PATH%" shell getprop debug.firebase.analytics.app
) else (
    adb shell getprop debug.firebase.analytics.app
)

echo.
echo ================================
echo NEXT STEPS:
echo ================================
echo 1. RESTART your Flutter app completely
echo 2. Login to your app
echo 3. Open Firebase Console > Analytics > DebugView
echo 4. You should see real-time events appear!
echo.
echo If you still don't see events, wait 1-2 minutes and refresh the page.
echo.
goto :end

:manual
echo.
echo ================================
echo MANUAL SETUP REQUIRED
echo ================================
echo.
echo Please run this command manually in your terminal:
echo.
echo   adb shell setprop debug.firebase.analytics.app com.example.license_prep_app
echo.
echo If adb is not found, install Android SDK Platform Tools:
echo https://developer.android.com/studio/releases/platform-tools
echo.
echo Or find adb.exe in your Android SDK folder:
echo %LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
echo.

:end
echo Press any key to exit...
pause >nul
