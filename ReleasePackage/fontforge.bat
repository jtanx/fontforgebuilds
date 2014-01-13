@echo OFF
set FF=%~dp0
set PATH=%FF%\bin;%FF%\bin\VcXsrv;%PATH%
set DISPLAY=:9.0
set XLOCALEDIR=%FF%\bin\VcXsrv\locale
set AUTOTRACE=potrace
set HOME=%FF%

start /B "" "%FF%\bin\VcXsrv\vcxsrv.exe" :9 -multiwindow -clipboard -silent-dup-error

"%FF%\bin\VcXsrv_close.exe" -wait

"%FF%\bin\fontforge.exe" -nosplash %*

"%FF%\bin\VcXsrv_close.exe" -close
