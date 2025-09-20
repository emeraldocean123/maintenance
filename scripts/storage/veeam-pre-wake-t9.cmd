@echo off
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%wake-usb-drive.ps1"
exit /b %ERRORLEVEL%

