@echo off
setlocal EnableExtensions
pushd "%~dp0"
if not exist "dist\web\index.html" (
  echo ERROR: Run BUILD_WEB.bat first.
  popd & exit /b 2
)
where python >nul 2>&1 || (
  echo ERROR: Python was not found.
  popd & exit /b 3
)
echo Open http://localhost:8060
python -m http.server 8060 --directory "dist\web"
popd
