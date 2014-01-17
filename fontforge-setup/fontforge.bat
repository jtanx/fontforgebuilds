@ECHO OFF
set FF=%~dp0
set PATH=%FF%\bin;%FF%\bin\VcXsrv;%PATH%
set DISPLAY=:9.0
set XLOCALEDIR=%FF%\bin\VcXsrv\locale
set AUTOTRACE=potrace

"%FF%\bin\VcXsrv_util.exe" -exists || (
start /B "" "%FF%\bin\VcXsrv\vcxsrv.exe" :9 -multiwindow -clipboard -silent-dup-error
)

"%FF%\bin\VcXsrv_util.exe" -wait

"%FF%\bin\fontforge.exe" -nosplash %*

"%FF%\bin\VcXsrv_util.exe" -close