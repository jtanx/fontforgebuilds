@ECHO OFF
set FF=%~dp0
set DISPLAY=127.0.0.1:9.0
set XLOCALEDIR=%FF%\bin\VcXsrv\locale
set AUTOTRACE=potrace
set HOME=%FF%
set FF_PORTABLE=TRUE
::Set this to your language code to change the FontForge UI language
::See share/locale/ for a list of supported language codes
::set LANGUAGE=en


::Only add to the path if it's not already there
set FFPATH=%FF%\bin
call "%FF%\bin\AddToPath" FFPATH /B || goto PathFail
set FFPATH=%FF%
call "%FF%\bin\AddToPath" FFPATH /B || goto PathFail

"%FF%\bin\VcXsrv_util.exe" -exists || (
start /B "" "%FF%\bin\VcXsrv\vcxsrv.exe" :9 -multiwindow -clipboard -silent-dup-error
)

"%FF%\bin\VcXsrv_util.exe" -wait

"%FF%\bin\fontforge.exe" -nosplash %*

goto ok

:PathFail
echo Failed to set the PATH variable

:ok
"%FF%\bin\VcXsrv_util.exe" -close
:: bye

