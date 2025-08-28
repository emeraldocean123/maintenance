@echo off
setlocal
set "ROOT=%~dp0.."
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
  "%ProgramFiles%\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\First-Run.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\First-Run.ps1" %*
)
endlocal

