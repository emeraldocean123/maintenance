@echo off
setlocal
set "SCRIPT=%~dp0..\maintain.ps1"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
  "%ProgramFiles%\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
)
endlocal

