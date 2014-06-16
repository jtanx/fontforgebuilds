@echo off
echo Configuring the system path to add FontForge...
set FF=%~dp0
set PATH=%FF%;%PATH%

echo Configuration complete. You can now call 'fontforge' from the console.
echo You may also use the bundled Python distribution by calling `ffpython.exe`.
echo Extra Python modules that you require may be installed via `ffpython.exe`.
echo.
cmd /k