@echo off
echo Configuring the system path to add FontForge...
set FF=%~dp0
set PATH=%FF%;%FF%\bin;%PATH%

echo Configuration complete. You can now call 'fontforge' from the console.
echo You may also use the bundled Python distribution by calling `ffpython`.
echo Extra Python modules that you require may be installed via `ffpython`.
echo.
cmd /k