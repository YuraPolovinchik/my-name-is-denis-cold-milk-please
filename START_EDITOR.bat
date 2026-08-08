@echo off
setlocal
pushd "%~dp0" || (
  echo Could not open the project folder.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\tools\run_project.ps1" -Mode Editor
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" pause
exit /b %RC%
