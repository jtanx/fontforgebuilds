@echo off
echo Configuring the system path to add FontForge...
set FF=%~dp0
set PATH=%FF%;%PATH%

echo Configuration complete. You can now call 'fontforge' from the console.
echo.
cmd /k