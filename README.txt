An unofficial FontForge build script for Windows.

This script was based on Matthew Petroff's work, although it was heavily 
modified to accommodate for changes to the FontForge build system, and
to also update some components to more recent versions.

Matthew Petroff is the author of the icons and graphics used, 
as well as the installer scripts:

* The installer is licensed under the BSD 3-Clause license.
* The icons and graphics are licensed under the
  Creative Commons Attribution 3.0 Unported license.

See here for more information: 
https://bitbucket.org/mpetroff/unofficial-fontforge-mingw-sdk/wiki/Home

The build script (ffbuild.sh) is licensed under the BSD 2-clause license.

--------------------------------------------------------------------------------

Build instructions:
1. Download and install the base MSYS2 system: 
   http://sourceforge.net/projects/msys2/
     - Make sure to get either the i686 (32 bit) or x86_64 (64 bit) version
       depending on your platform.
     - Use an archiver tool like 7-zip to extract it to some location,
       *making sure* that the location *does not* contain spaces.
	     - For example, extract it to "C:\msys"
2. Initialise MSYS2 - double click on mingw32_shell.bat. You should be prompted
   to restart the shell after it initialises a few things.
3. Open the shell again, and extract the contents of this build system to your
   home directory.
     - e.g: Extract ffbuild.zip to C:\msys\home\your_username\ffbuild
     - You should be able to see this folder from the shell when you type `ls`.
4.  
5. In the shell, enter the directory (e.g `cd ffbuild`) and run the build script:
     - ./ffbuild.sh
