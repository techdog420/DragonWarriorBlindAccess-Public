@echo off
setlocal EnableExtensions

set "INSTALL_SCRIPT=%~dp0app\install_player.ps1"
if not exist "%INSTALL_SCRIPT%" set "INSTALL_SCRIPT=%~dp0install_player.ps1"

if not exist "%INSTALL_SCRIPT%" (
    echo Dragon Warrior setup cannot start.
    echo Missing installer script: %INSTALL_SCRIPT%
    echo Extract the complete release ZIP and try again.
    pause
    exit /b 4
)

if "%~1"=="" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_SCRIPT%" -PackageRoot "%~dp0."
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_SCRIPT%" -PackageRoot "%~dp0." -RomPath "%~1"
)
set "INSTALL_EXIT=%ERRORLEVEL%"

echo.
if "%INSTALL_EXIT%"=="0" (
    echo ROM setup finished successfully.
) else (
    echo Setup did not complete. Exit code %INSTALL_EXIT%.
    echo Review the messages above or open user\install.log.
)
pause
exit /b %INSTALL_EXIT%
