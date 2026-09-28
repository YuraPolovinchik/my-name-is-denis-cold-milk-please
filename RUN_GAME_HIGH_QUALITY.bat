@echo off
setlocal
pushd "%~dp0" || exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\tools\run_project.ps1" -Mode Game -HighQuality
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
