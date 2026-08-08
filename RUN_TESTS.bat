@echo off
setlocal
pushd "%~dp0" || (
  echo Could not open the project folder.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\tools\run_project.ps1" -Mode Tests
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo Tests finished without a process error.
) else (
  echo Tests failed with exit code %RC%.
)
popd
pause
exit /b %RC%
