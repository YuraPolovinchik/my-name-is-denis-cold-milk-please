@echo off
setlocal
pushd "%~dp0" || (
  echo Could not open the project folder.
  pause
  exit /b 1
)
echo Installing portable Godot 4.4.1...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\tools\install_godot.ps1"
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" (
  echo.
  echo Installation failed. See the error above.
  pause
  exit /b %RC%
)
echo.
echo Godot is ready.
pause
exit /b 0
