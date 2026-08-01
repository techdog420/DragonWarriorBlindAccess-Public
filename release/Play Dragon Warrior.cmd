@echo off
setlocal EnableExtensions

set "PLAYER_SCRIPT=%~dp0app\play_player.ps1"
if not exist "%PLAYER_SCRIPT%" set "PLAYER_SCRIPT=%~dp0play_player.ps1"

if not exist "%PLAYER_SCRIPT%" (
    echo Dragon Warrior cannot start.
    echo Missing player launcher: %PLAYER_SCRIPT%
    echo Extract the complete release ZIP and try again.
    pause
    exit /b 4
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PLAYER_SCRIPT%" -PackageRoot "%~dp0"
set "PLAYER_EXIT=%ERRORLEVEL%"

if not "%PLAYER_EXIT%"=="0" (
    echo.
    echo Dragon Warrior did not start. Exit code %PLAYER_EXIT%.
    echo Review the messages above or open user\launch.log.
    pause
)
exit /b %PLAYER_EXIT%
