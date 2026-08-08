@echo off
setlocal EnableExtensions
pushd "%~dp0"

set "GODOT=tools\godot\4.4-stable\Godot_v4.4.1-stable_win64_console.exe"
if not exist "%GODOT%" (
  for %%G in (godot4.exe godot.exe) do if not defined GODOT_FOUND for /f "delims=" %%P in ('where %%G 2^>nul') do set "GODOT_FOUND=%%P"
  if not defined GODOT_FOUND (
    echo ERROR: Godot 4.4.1 was not found.
    popd & exit /b 2
  )
  set "GODOT=%GODOT_FOUND%"
)

for /f "delims=" %%V in ('"%GODOT%" --version') do set "GODOT_VERSION=%%V"
echo %GODOT_VERSION% | findstr /b /c:"4.4.1" >nul || (
  echo ERROR: Godot 4.4.1 is required, found %GODOT_VERSION%.
  popd & exit /b 3
)

if not exist "%APPDATA%\Godot\export_templates\4.4.1.stable\web_nothreads_release.zip" (
  echo ERROR: Official Godot 4.4.1 export templates are not installed.
  popd & exit /b 4
)

if exist "dist\web" rmdir /s /q "dist\web"
mkdir "dist\web" || (popd & exit /b 5)

"%GODOT%" --headless --path . --export-release "Web" "dist/web/index.html"
if errorlevel 1 (popd & exit /b 6)

if not exist "dist\web\index.html" (echo ERROR: index.html is missing.& popd & exit /b 7)
dir /b "dist\web\*.wasm" >nul 2>&1 || (echo ERROR: WASM is missing.& popd & exit /b 8)
dir /b "dist\web\*.pck" >nul 2>&1 || (echo ERROR: PCK is missing.& popd & exit /b 9)
powershell -NoProfile -Command "New-Item -ItemType File -Force -Path 'dist\web\.nojekyll' | Out-Null; $s=(Get-ChildItem 'dist\web' -File -Recurse | Measure-Object Length -Sum).Sum; Write-Host ('WEB_BUILD_OK: {0:N2} MB' -f ($s / 1MB))"

popd
exit /b 0
