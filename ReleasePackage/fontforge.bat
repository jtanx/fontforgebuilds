@ECHO OFF
set FF=%~dp0
set PATH=%FF%\bin;%FF%\bin\VcXsrv;%PATH%
set DISPLAY=127.0.0.1:9.0
set XLOCALEDIR=%FF%\bin\VcXsrv\locale
set AUTOTRACE=potrace
set HOME=%FF%
set FF_PORTABLE=TRUE

"%FF%\bin\VcXsrv_util.exe" -exists || (
start /B "" "%FF%\bin\VcXsrv\vcxsrv.exe" :9 -multiwindow -clipboard -silent-dup-error
)

"%FF%\bin\VcXsrv_util.exe" -wait

"%FF%\bin\fontforge.exe" -nosplash %*

"%FF%\bin\VcXsrv_util.exe" -close