@echo off
setlocal
pushd "%~dp0" || (
  echo Could not open the project folder.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\tools\run_project.ps1" -Mode Game
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" (
  echo.
  echo Godot returned error code %RC%.
  echo Run RUN_TESTS.bat to see script and project errors.
  pause
)
exit /b %RC%
