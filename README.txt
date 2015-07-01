An unofficial FontForge build script for Windows.

This script was based on Matthew Petroff's work, although it has
been practically rewritten since.

Matthew Petroff is the author of the icons and graphics used:
* The icons and graphics are licensed under the
  Creative Commons Attribution 3.0 Unported license.

See here for more information: 
https://bitbucket.org/mpetroff/unofficial-fontforge-mingw-sdk/wiki/Home

The build script (ffbuild.sh) and installer is licensed under the 
BSD 2-clause license.

--------------------------------------------------------------------------------

Build instructions:
See https://sourceforge.net/p/fontforgebuilds/wiki/Using%20the%20build%20script/

--------------------------------------------------------------------------------

CHANGELOG:
01/07/15
* Another overhaul to use precompiled X11, libspiro and libuninameslist
  libraries by default. This should speed up compiling FontForge from
  complete scratch. Cairo and Pango are still compiled by default, since
  these libraries may be used by other programs, and the versions compiled
  against X11 are not completely compatible with these programs.
14/06/14
* Overhauled the build system to allow building 32 and 64 bit builds in one
  MSYS2 installation.
  -  Compiled files are now built to the prefix target/mingw[32/64]/ so that 
     the MSYS2 system so it's reusable / easy to remove/redo compilation of
	 the files.
  - If you were using an older build script, it's highly recommended to
    start with a fresh MSYS2 installation.
* Patched libxcb (courtesy of the VcXsrv project) so that FontForge now
  works with the latest version of libX11. Probably fixes a fair few GUI
  bugs.
* Added a 'msys2-configs' branch that patches the MSYS2 configuration
  to make using the terminal and git nicer.
