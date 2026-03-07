@echo off
setlocal

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
set "ENGINE_DIR=C:\Dev\Game\Godot\Engine"

if defined GODOT_EXE if exist "%GODOT_EXE%" set "GODOT=%GODOT_EXE%"
if not defined GODOT if exist "%ENGINE_DIR%\Godot_v4.4.1-stable_win64_console.exe" set "GODOT=%ENGINE_DIR%\Godot_v4.4.1-stable_win64_console.exe"
if not defined GODOT if exist "%ENGINE_DIR%\Godot_v4.5-stable_win64_console.exe" set "GODOT=%ENGINE_DIR%\Godot_v4.5-stable_win64_console.exe"
if not defined GODOT if exist "%ENGINE_DIR%\Godot_v4.4.1-stable_win64.exe" set "GODOT=%ENGINE_DIR%\Godot_v4.4.1-stable_win64.exe"
if not defined GODOT if exist "%ENGINE_DIR%\Godot_v4.5-stable_win64.exe" set "GODOT=%ENGINE_DIR%\Godot_v4.5-stable_win64.exe"

if not defined GODOT (
    echo Could not find a Godot executable.
    echo Looked in "%ENGINE_DIR%" and optional GODOT_EXE environment variable.
    pause
    exit /b 1
)

"%GODOT%" --path "%PROJECT_DIR%"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
    echo.
    echo Godot exited with code %EXIT_CODE%.
    pause
)
exit /b %EXIT_CODE%
