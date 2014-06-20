@ECHO OFF
set FF=%~dp0
set DISPLAY=127.0.0.1:9.0
set XLOCALEDIR=%FF%\bin\VcXsrv\locale
set AUTOTRACE=potrace
set HOME=%FF%
::Set this to your language code to change the FontForge UI language
::See share/locale/ for a list of supported language codes
::set LANGUAGE=en

::Only add to path once
if not defined FF_PATH_ADDED (
set PATH=%FF%;%FF%\bin;%PATH%
set FF_PATH_ADDED=TRUE
)

"%FF%\bin\VcXsrv_util.exe" -exists || (
start /B "" "%FF%\bin\VcXsrv\vcxsrv.exe" :9 -multiwindow -clipboard -silent-dup-error
)

"%FF%\bin\VcXsrv_util.exe" -wait

"%FF%\bin\fontforge.exe" -nosplash %*

"%FF%\bin\VcXsrv_util.exe" -close
:: bye

