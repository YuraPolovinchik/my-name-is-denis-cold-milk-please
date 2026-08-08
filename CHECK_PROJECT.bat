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
  echo Project check completed. Look for both DENIS test markers above.
) else (
  echo Project check failed with exit code %RC%.
)
popd
pause
exit /b %RC%
