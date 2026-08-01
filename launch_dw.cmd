@echo off
setlocal EnableExtensions
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] date=%date% time=%time%
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] cmdline=%cmdcmdline%
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] raw1=%1
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] raw2=%2
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] raw3=%3
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] raw4=%4

if "%~3"=="" goto usage

set "FCEUX_EXE=%~1"
set "ROM_PATH=%~2"
set "LUA_PATH=%~3"
set "STATE_SLOT=%~4"
set "EMULATOR_DIR=%~dp1"
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] fceux_exe=%FCEUX_EXE%
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] rom_path=%ROM_PATH%
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] lua_path=%LUA_PATH%
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] state_slot=%STATE_SLOT%
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] emulator_dir=%EMULATOR_DIR%

if not exist "%FCEUX_EXE%" goto missing_fceux

if not exist "%ROM_PATH%" goto missing_rom

if not exist "%LUA_PATH%" goto missing_lua

if "%DW_LAUNCH_CONFIG_LUA_ONLY%"=="1" goto config_lua_only

if "%DW_LAUNCH_ROM_FIRST%"=="1" goto rom_first

if "%DW_LAUNCH_SPLIT_LOADLUA%"=="1" goto split_loadlua

if "%STATE_SLOT%"=="" goto launch_without_slot

if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=launch_with_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] command=start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "--loadstate" "%STATE_SLOT%" "--loadlua" "%LUA_PATH%" "%ROM_PATH%"
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "--loadstate" "%STATE_SLOT%" "--loadlua" "%LUA_PATH%" "%ROM_PATH%"
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] start_errorlevel=%ERRORLEVEL%
exit /b %ERRORLEVEL%

:launch_without_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=launch_without_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] command=start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "--loadlua" "%LUA_PATH%" "%ROM_PATH%"
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "--loadlua" "%LUA_PATH%" "%ROM_PATH%"
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] start_errorlevel=%ERRORLEVEL%
exit /b %ERRORLEVEL%

:rom_first
if "%DW_LAUNCH_SPLIT_LOADLUA%"=="1" goto split_loadlua_rom_first
if "%STATE_SLOT%"=="" goto launch_without_slot_rom_first

if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=launch_with_slot_rom_first
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] command=start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "%ROM_PATH%" "--loadstate" "%STATE_SLOT%" "--loadlua" "%LUA_PATH%"
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "%ROM_PATH%" "--loadstate" "%STATE_SLOT%" "--loadlua" "%LUA_PATH%"
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] start_errorlevel=%ERRORLEVEL%
exit /b %ERRORLEVEL%

:config_lua_only
if "%STATE_SLOT%"=="" goto config_lua_only_without_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=config_lua_only_with_slot
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "%ROM_PATH%" "--loadstate" "%STATE_SLOT%"
exit /b %ERRORLEVEL%

:config_lua_only_without_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=config_lua_only_without_slot
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "%ROM_PATH%"
exit /b %ERRORLEVEL%

:split_loadlua
if "%STATE_SLOT%"=="" goto split_loadlua_without_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=split_loadlua_with_slot
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "--loadstate" "%STATE_SLOT%" "--loadlua" "%LUA_PATH%" "%ROM_PATH%"
exit /b %ERRORLEVEL%

:split_loadlua_without_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=split_loadlua_without_slot
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "--loadlua" "%LUA_PATH%" "%ROM_PATH%"
exit /b %ERRORLEVEL%

:split_loadlua_rom_first
if "%STATE_SLOT%"=="" goto split_loadlua_rom_first_without_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=split_loadlua_rom_first_with_slot
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "%ROM_PATH%" "--loadstate" "%STATE_SLOT%" "--loadlua" "%LUA_PATH%"
exit /b %ERRORLEVEL%

:split_loadlua_rom_first_without_slot
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=split_loadlua_rom_first_without_slot
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "%ROM_PATH%" "--loadlua" "%LUA_PATH%"
exit /b %ERRORLEVEL%

:launch_without_slot_rom_first
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] branch=launch_without_slot_rom_first
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] command=start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "%ROM_PATH%" "--loadlua" "%LUA_PATH%"
start "" /D "%EMULATOR_DIR%" "%FCEUX_EXE%" "%ROM_PATH%" "--loadlua" "%LUA_PATH%"
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] start_errorlevel=%ERRORLEVEL%
exit /b %ERRORLEVEL%

:usage
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] error=usage
>&2 echo Usage: launch_dw.cmd ^<fceux.exe^> ^<rom.nes^> ^<script.lua^> [state_slot]
exit /b 2

:missing_fceux
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] error=missing_fceux
>&2 echo FCEUX executable not found: %FCEUX_EXE%
exit /b 3

:missing_rom
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] error=missing_rom
>&2 echo ROM not found: %ROM_PATH%
exit /b 4

:missing_lua
if "%DW_LAUNCH_DEBUG%"=="1" echo [launch_dw.cmd] error=missing_lua
>&2 echo Lua script not found: %LUA_PATH%
exit /b 5
