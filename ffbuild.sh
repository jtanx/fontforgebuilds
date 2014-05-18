#!/bin/sh
# FontForge build script.
# Uses MSYS2/MinGW-w64
# Author: Jeremy Tan
# Usage: ffbuild.sh [--reconfigure]
# --reconfigure     Forces the configure script to be rerun for the currently 
#                   worked-on package.
#
# This script retrieves and installs all libraries required to build FontForge.
# It then attempts to compile the latest version of FontForge, and to 
# subsequently make a redistributable package.

# Retrieve input arguments to script
reconfigure="$1"

# Set working folders
BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PATCH=$BASE/patches
WORK=$BASE/work
UIFONTS=$BASE/ui-fonts
SOURCE=$BASE/original-archives/sources/
BINARY=$BASE/original-archives/binaries/
RELEASE=$BASE/ReleasePackage/
HOST="--build=i686-w64-mingw32 --host=i686-w64-mingw32 --target=i686-w64-mingw32"

# Set pkg-config path to also search mingw libs
export PKG_CONFIG_PATH=/mingw32/lib/pkgconfig:/usr/local/lib/pkgconfig:/lib/pkgconfig:/usr/local/share/pkgconfig

# Compiler flags
export LDFLAGS="-L/mingw32/lib -L/usr/local/lib -L/lib" 
export CFLAGS="-DWIN32 -I/mingw32/include -I/usr/local/include -I/include -g"
export CPPFLAGS="${CFLAGS}"
export LIBS=""
export XPROTO_CFLAGS="${CFLAGS}"
export XPROTO_LIBS="${LDFLAGS}"
export XKBPROTO_CFLAGS="${CFLAGS}"
export XKBPROTO_LIBS="${LDFLAGS}"
export XAU_CFLAGS="${CFLAGS}"
export XAU_LIBS="${LDFLAGS}"
export XDMCP_CFLAGS="${CFLAGS}"
export XDMCP_LIBS="${LDFLAGS} -lws2_32"
export XKBFILE_CFLAGS="${CFLAGS}"
export XKBFILE_LIBS="${LDFLAGS} -lX11"
export XKBUI_CFLAGS="${CFLAGS}"
export XKBUI_LIBS="${LDFLAGS} -lX11 -lxkbfile"
export X11_CFLAGS="${CFLAGS}"
export X11_LIBS="${LDFLAGS} -lXdmcp -lXau -lpthread"
export ICE_CFLAGS="${CFLAGS}"
export ICE_LIBS="${LDFLAGS}"

# Make the output directories
mkdir -p "$WORK"
mkdir -p "$RELEASE/bin"
mkdir -p "$RELEASE/lib"
mkdir -p "$RELEASE/share"

# Red text
function log_error() {
    echo -e "\e[31m$@\e[0m"
}

# Yellow text
function log_status() {
    echo -e "\e[33m$@\e[0m"
}

# Green text
function log_note() {
    echo -e "\e[32m$@\e[0m"
}

function bail () {
    echo -e "\e[31m\e[1m!!! Build failed at: ${@}\e[0m"
    exit 1
}

log_note "MSYS2 FontForge build script..."

# Install all the available precompiled binaries
if [ ! -f $BASE/.pacman-installed ]; then
    log_status "First time run; installing MSYS and MinGW libraries..."

    # Add the mingw repository and update pacman.
    # Also updates all packages to the latest.
    # Not needed anymore with latest version of MSYS2
    # cp -f $PATCH/pacman.conf /etc/
    pacman -Sy --noconfirm

    IOPTS="-S --noconfirm --needed"
    # Install the base MSYS packages needed
    pacman $IOPTS diffutils findutils gawk liblzma m4 make patch tar xz

    ## Automake stuff
    pacman $IOPTS automake autoconf pkg-config

    ## Other libs
    pacman $IOPTS git mingw-w64-i686-python2 mingw-w64-i686-openssl # libxslt docbook-xml docbook-xsl

    # Install MinGW related stuff
    pacman $IOPTS binutils mingw-w64-i686-gcc mingw-w64-i686-gcc-fortran mingw-w64-i686-gmp
    pacman $IOPTS mingw-w64-i686-gettext mingw-w64-i686-libiconv mingw-w64-i686-libtool

    log_status "Installing precompiled devel libraries..."

    # Libraries
    pacman $IOPTS mingw-w64-i686-zlib mingw-w64-i686-libpng mingw-w64-i686-giflib mingw-w64-i686-libtiff
    pacman $IOPTS mingw-w64-i686-libjpeg-turbo mingw-w64-i686-libxml2 mingw-w64-i686-freetype
    pacman $IOPTS mingw-w64-i686-fontconfig mingw-w64-i686-glib2
    pacman $IOPTS mingw-w64-i686-harfbuzz mingw-w64-i686-gc #BDW Garbage collector

    #log_status "Patching faulty pyconfig.h..."
    #patch -p0 /include/python2.7/pyconfig.h $PATCH/pyconfig.patch
    touch $BASE/.pacman-installed
    log_note "Finished installing precompiled libraries!"
else
    log_note "Detected that precompiled libraries are already installed."
    log_note "  Delete '$BASE/.pacman-installed' and run this script again if"
    log_note "  this is not the case."
fi # pacman installed

# Install from tarball
# install_source_raw(file, folder_name, patch, configflags, premakeflags, postmakeflags)
function install_source_patch () {
    local file=$1
    local folder=$2
    local patch=$3
    local configflags=$4
    local premakeflags=$5
    local postmakeflags=$6
    
    # Default to the name of the archive, if folder name is not given
    if [ -z "$folder" ]; then
        local filename="$(basename $1)"
        folder="${filename%.tar*}"
    fi
    
    cd $WORK
    if [ ! -f "$folder/$folder.complete"  ]; then
        log_status "Installing $folder..."
        if [ ! -d "$folder" ]; then
            tar axvf $SOURCE$file || bail "$folder"
        else
            log_note "Sensing incomplete build, re-attempting the build..."
        fi
        
        cd $folder || bail "$folder"
        if [ ! -z $patch ]; then
            log_status "Patching $folder with $patch..."
            # Check if it's already been applied or not
            patch -p1 -N --dry-run --silent < $PATCH/$patch 2>/dev/null
            if [ $? -eq 0 ]; then
                patch -p1 < $PATCH/$patch || bail "$folder"
            else
                log_note "Sensed that patch has already been applied; skipping"
            fi
        fi
        
        if [ ! -f "$folder.configure-complete" ] || [ "$reconfigure" = "--reconfigure" ]; then
            log_status "Running the configure script..."
            ./configure $HOST $configflags || bail "$folder"
            touch "$folder.configure-complete"
        else
            log_note "Sensed that the configure script has already run; delete $folder.configure-complete to rerun configure"
        fi
        cmd="$premakeflags make -j4 $postmakeflags || bail '$folder'"
        log_note "$cmd"
        eval "$cmd"
        make install || bail "$folder"
        log_status "Installation complete!"
        
        touch "$folder.complete"
        cd ..
    fi
}

# install_source(file, folder_name, configflags, premakeflags, postmakeflags)
function install_source () {
    install_source_patch "$1" "$2" "" "${@:3}"
}

# install_source(git_link, folder_name, custom_configgen, configflags, premakeflags, postmakeflags)
function install_git_source () {
    cd $WORK
    
    log_status "Attempting git install of $2..."
    if [ ! -d "$2" ]; then
        log_status "Cloning git repository from $1..."
        git clone "$1" "$2" || bail "Git clone of $1"
        cd "$2"
    else
        cd "$2"
        log_status "Attempting update of git repository..."
        #git pull --rebase || log_note "Failed to update. Unstaged changes?"
    fi
    
    if [ ! -f .gen-configure-complete ]; then
        log_status "Generating configure files..."
        if [ ! -z "$3" ]; then
            eval "$3" || bail "Failed to generate makefiles"
        else
            ./autogen.sh || bail "Failed to autogen"
        fi
        touch .gen-configure-complete
    fi
    
    cd ..
    install_source "" "$2" "${@:4}"
    
}

log_status "Installing custom libraries..."
install_git_source "http://github.com/fontforge/libspiro" "libspiro" "libtoolize -i && autoreconf -i && automake --foreign -Wall"
install_git_source "http://github.com/fontforge/libuninameslist" "libuninameslist" "libtoolize -i && autoreconf -i && automake --foreign"


# X11 libraries
log_status "Installing X11 libraries..."

xproto=X.Org/proto
xlib=X.Org/lib
xcb=X.Org/xcb

# Download from: http://xorg.freedesktop.org/releases/individual/proto
install_source $xproto/bigreqsproto-1.1.2.tar.bz2
install_source $xproto/inputproto-2.3.tar.bz2
install_source $xproto/kbproto-1.0.6.tar.bz2
install_source $xproto/xcmiscproto-1.2.2.tar.bz2
install_source $xproto/xproto-7.0.26.tar.bz2
install_source $xproto/xextproto-7.3.0.tar.bz2
install_source $xproto/renderproto-0.11.1.tar.bz2

# Download from: http://xorg.freedesktop.org/releases/individual/lib
install_source $xlib/xtrans-1.3.4.tar.bz2
install_source $xlib/libXau-1.0.8.tar.bz2
install_source $xlib/libXdmcp-1.1.1.tar.bz2

install_source_patch $xlib/libX11-1.3.6.tar.bz2 "" "libx11.patch" \
    "
    --enable-static
    --without-xcb
    --disable-unix-transport
    --disable-local-transport
    --disable-xf86bigfont
    --disable-loadable-xcursor
    --enable-xlocaledir
    "

#install_source $xcb/xcb-proto-1.10.tar.bz2
#install_source $xcb/libpthread-stubs-0.3.tar.bz2
#install_source $xcb/libxcb-1.10.tar.bz2 "" "LIBS=-lXdmcp"

#install_source $xlib/libX11-1.6.2.tar.bz2 "" \
#    "
#    LIBS=-lxcb
#    --disable-xf86bigfont
#    --enable-xlocaledir 
#    "
    
install_source $xlib/libxkbfile-1.0.8.tar.bz2
install_source $xlib/libxkbui-1.0.2.tar.bz2
install_source $xlib/libXext-1.3.2.tar.bz2
install_source $xlib/libXrender-0.9.8.tar.bz2
install_source_patch $xlib/libXft-2.3.1.tar.bz2 "" "libxft.patch"

install_source_patch $xlib/libICE-1.0.8.tar.bz2 "" "libice.patch"
install_source_patch $xlib/libSM-1.2.2.tar.bz2 "" "libsm.patch"

# Download from http://ftp.gnome.org/pub/gnome/sources/pango
log_status "Installing Pango..."
install_source pango-1.36.3.tar.xz "" "--with-xft"

# ZMQ does not work for now
#install_git_source "https://github.com/jedisct1/libsodium" "libsodium" "libtoolize -i && ./autogen.sh"
#install_git_source "https://github.com/zeromq/libzmq" "libzmq" "libtoolize -i && ./autogen.sh"
#install_git_source "https://github.com/zeromq/czmq" "czmq" "libtoolize -i && ./autogen.sh"


# VcXsrv_util
if [ ! -f VcXsrv_util/VcXsrv_util.complete ]; then
    log_status "Building VcXsrv_util..."
    mkdir -p VcXsrv_util
    cd VcXsrv_util
    gcc -Wall -O2 -municode \
        -o VcXsrv_util.exe "$PATCH/VcXsrv_util.c" \
    || bail "VcXsrv_util"
    touch VcXsrv_util.complete
    cd ..
fi

# run_fontforge
if [ ! -f run_fontforge/run_fontforge.complete ]; then
    log_status "Installing run_fontforge..."
    mkdir -p run_fontforge
    cd run_fontforge
    windres "$PATCH/run_fontforge.rc" -O coff -o run_fontforge.res
    gcc -Wall -O2 -mwindows -o run_fontforge.exe "$PATCH/run_fontforge.c" run_fontforge.res \
    || bail "run_fontforge"
    touch run_fontforge.complete
    cd ..
fi

# For the source only; to enable the debugger in FontForge
if [ ! -d freetype-2.5.3 ]; then
    log_status "Extracting the FreeType 2.5.3 source..."
    tar axvf "$SOURCE/freetype-2.5.3.tar.bz2" || bail "FreeType2 extraction"
fi

log_status "Finished installing prerequisites, attempting to install FontForge!"
cd $WORK

# fontforge
if [ ! -d fontforge ]; then
    log_status "Cloning the fontforge repository"
    git clone https://github.com/jtanx/fontforge || bail "Cloning fontforge"
    cd fontforge 
    git checkout win32 || bail "Checking out win32 branch"
else
    cd fontforge
fi

if [ ! -f fontforge.configure-complete ] || [ "$reconfigure" = "--reconfigure" ]; then
    log_status "Running the configure script..."
    
    if [ ! -f configure ]; then
        log_note "No configure script detected; running ./boostrap..."
        #./autogen.sh || bail "FontForge autogen"
        ./bootstrap || bail "FontForge autogen"
        #log_note "Patching lib files to use <fontforge-config.h>..."
        #sed -bi "s/<config\.h>/<fontforge-config.h>/" lib/*.c
    fi

    # libreadline is disabled because it causes issues when used from the command line (e.g Ctrl+C doesn't work)
    # windows-cross-compile to disable check for libuuid
    
    # Crappy hack to get around forward slash in path issues 
    #am_cv_python_pythondir=/usr/lib/python2.7/site-packages \
    #am_cv_python_pyexecdir=/usr/lib/python2.7/site-packages \
    ./configure $HOST \
        --enable-shared \
        --disable-static \
        --enable-windows-cross-compile \
        --datarootdir=/usr/share/share_ff \
        --without-cairo \
        --without-libzmq \
        --with-freetype-source="$WORK/freetype-2.5.3" \
        --without-libreadline \
        || bail "FontForge configure"
    touch fontforge.configure-complete
fi

log_status "Compiling FontForge..."
make -j 4	|| bail "FontForge make"

log_status "Installing FontForge..."
make -j 4 install || bail "FontForge install"

log_status "Assembling the release package..."
ffex=`which fontforge.exe`
fflibs=`ldd "$ffex" \
| grep dll \
| sed -e '/^[^\t]/ d'  \
| sed -e 's/\t//'  \
| sed -e 's/.*=..//'  \
| sed -e 's/ (0.*)//'  \
| sed -e '/^\/c/d' \
| sort  \
| uniq \
`

log_status "Copying the FontForge executable..."
strip "$ffex" -so "$RELEASE/bin/fontforge.exe"
log_status "Copying the libraries required by FontForge..."
for f in $fflibs; do
    filename="$(basename $f)"
    strip "$f" -so "$RELEASE/bin/$filename"
done

log_status "Copying the shared folder of FontForge..."
cp -rf /usr/share/share_ff/fontforge "$RELEASE/share/"
cp -rf /usr/share/share_ff/locale "$RELEASE/share/"
rm -f "$RELEASE/share/prefs"

log_note "Installing custom binaries..."
cd $WORK
# potrace - http://potrace.sourceforge.net/#downloading
if [ ! -f $RELEASE/bin/potrace.exe ]; then
    log_status "Installing potrace..."
    mkdir -p potrace
    cd potrace
    if [ ! -d potrace-1.11.win32 ]; then
        tar axvf $BINARY/potrace-1.11.win32.tar.gz
    fi
    strip potrace-1.11.win32/potrace.exe -so $RELEASE/bin/potrace.exe
    cd ..
fi

#VcXsrv - Xming replacement
if [ ! -d $RELEASE/bin/VcXsrv ]; then
    log_status "Installing VcXsrv..."
    if [ ! -d VcXsrv ]; then
        tar axvf $BINARY/VcXsrv-1.14.2-minimal.tar.bz2
    fi
    cp -rf VcXsrv $RELEASE/bin/
fi

log_status "Installing VcXsrv_util..."
strip $WORK/VcXsrv_util/VcXsrv_util.exe -so "$RELEASE/bin/VcxSrv_util.exe" \
    || bail "VcxSrv_util"
log_status "Installing run_fontforge..."
strip $WORK/run_fontforge/run_fontforge.exe -so "$RELEASE/run_fontforge.exe" \
    || bail "run_fontforge"

log_status "Copying the Pango modules..."
cp -rf /usr/local/lib/pango "$RELEASE/lib"

log_status "Copying UI fonts..."
mkdir -p "$RELEASE/share/fonts"
cp "$UIFONTS"/* "$RELEASE/share/fonts/"
cp /usr/share/share_ff/fontforge/pixmaps/Cantarell* "$RELEASE/share/fonts"

log_status "Copying sfd icon..."
cp "$PATCH/artwork/sfd-icon.ico" "$RELEASE/share/fontforge/"

log_status "Copying the Python libraries..."
if [ -d "$RELEASE/lib/python2.7" ]; then
    log_note "Skipping python library copy because folder already exists, and copying is slow."
else  
    cp -r "$BINARY/python2.7" "$RELEASE/lib"
fi

log_status "Copying OpenSSL libraries (for Python hashlib)..."
cp /mingw32/bin/libeay32.dll "$RELEASE/bin"

log_status "Setting the git version number..."
version_hash=`git -C $WORK/fontforge rev-parse master`
current_date=`date "+%c %z"`
if [ ! -f $RELEASE/VERSION.txt ]; then
	printf "FontForge Windows build\ngit " > $RELEASE/VERSION.txt
fi

sed -bi "s/^git .*$/git $version_hash ($current_date).\r/g" $RELEASE/VERSION.txt

log_note "Build complete."















