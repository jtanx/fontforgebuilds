#!/bin/sh
# FontForge build script.
# Uses MSYS2/MinGW-w64
# Author: Jeremy Tan
# Usage: ffbuild.sh [--reconfigure|--nomake --noconfirm]
# --reconfigure     Forces the configure script to be rerun for the currently 
#                   worked-on package.
# --nomake          Don't make/make install FontForge but do everything else
# --noconfirm       Don't confirm when switching between the build architecture.
#
# This script retrieves and installs all libraries required to build FontForge.
# It then attempts to compile the latest version of FontForge, and to 
# subsequently make a redistributable package.

# Retrieve input arguments to script
opt1="$1"
opt2="$2"

# Colourful text
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

function detect_arch_switch () {
    local from=".building-$1"
    local to=".building-$2"
    
    if [ -f "$from" ]; then
        if [ "$opt2" = "--yes" ]; then
            git clean -dxf "$RELEASE" || bail "Could not reset ReleasePackage"
        else
            read -p "Architecture change detected! ReleasePackage must be reset. Continue? [y/N]: " arch_confirm
            case $arch_confirm in
                [Yy]* ) git clean -dxf "$RELEASE" || bail "Could not reset ReleasePackage"; break;;
                * ) bail "Not overwriting ReleasePackage" ;;
            esac
        fi
    fi
    
    rm -f $from
    touch $to
}

# Preamble
log_note "MSYS2 FontForge build script..."

# Set working folders
BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PATCH=$BASE/patches/
UIFONTS=$BASE/ui-fonts/
SOURCE=$BASE/original-archives/sources/
BINARY=$BASE/original-archives/binaries/
RELEASE=$BASE/ReleasePackage/
DBSYMBOLS=$BASE/debugging-symbols/.debug/

# Determine if we're building 32 or 64 bit.
if [ "$MSYSTEM" = "MINGW32" ]; then
    log_note "Building 32-bit version!"

    ARCH="32-bit"
    MINGVER=mingw32
    MINGOTHER=mingw64
    HOST="--build=i686-w64-mingw32 --host=i686-w64-mingw32 --target=i686-w64-mingw32"
    PMPREFIX="mingw-w64-i686"
    PYINST=python2
    PYVER=python2.7
    VCXSRV="VcXsrv-1.14.2-minimal.tar.bz2"
    POTRACE_DIR="potrace-1.11.win32"
elif [ "$MSYSTEM" = "MINGW64" ]; then
    log_note "Building 64-bit version!"

    ARCH="64-bit"
    MINGVER=mingw64
    MINGOTHER=mingw32
    HOST="--build=x86_64-w64-mingw32 --host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32"
    PMPREFIX="mingw-w64-x86_64"
    PYINST=python3
    PYVER=python3.4
    VCXSRV="VcXsrv-1.15.0.2-x86_64-minimal.tar.bz2"
    POTRACE_DIR="potrace-1.11.win64"
else 
    bail "Unknown build system!"
fi

# Early detection
detect_arch_switch $MINGOTHER $MINGVER

# Common options
TARGET=$BASE/target/$MINGVER/
WORK=$BASE/work/$MINGVER/
HOST="$HOST --prefix $TARGET"
PMTEST="$BASE/.pacman-$MINGVER-installed"
POTRACE_ARC="$POTRACE_DIR.tar.gz"


# Make the output directories
mkdir -p "$WORK"
mkdir -p "$RELEASE/bin"
mkdir -p "$RELEASE/lib"
mkdir -p "$RELEASE/share"
mkdir -p "$DBSYMBOLS"
mkdir -p "$TARGET/bin"
mkdir -p "$TARGET/lib/pkgconfig"
mkdir -p "$TARGET/include"
mkdir -p "$TARGET/share"


# Set pkg-config path to also search mingw libs
export PATH="$TARGET/bin:$PATH"
export PKG_CONFIG_PATH="$TARGET/share/pkgconfig:$TARGET/lib/pkgconfig:/$MINGVER/lib/pkgconfig:/usr/local/lib/pkgconfig:/lib/pkgconfig:/usr/local/share/pkgconfig"
# aclocal path
export ACLOCAL="aclocal -I $TARGET/share/aclocal -I /$MINGVER/share/aclocal"
# Compiler flags
export LDFLAGS="-L$TARGET/lib -L/$MINGVER/lib -L/usr/local/lib -L/lib" 
export CFLAGS="-DWIN32 -I$TARGET/include -I/$MINGVER/include -I/usr/local/include -I/include -g"
export CPPFLAGS="${CFLAGS}"
export LIBS=""


# Install all the available precompiled binaries
if [ ! -f $PMTEST ]; then
    log_status "First time run; installing MSYS and MinGW libraries..."

    pacman -Sy --noconfirm

    IOPTS="-S --noconfirm --needed"
    # Install the base MSYS packages needed
    pacman $IOPTS diffutils findutils gawk liblzma m4 make patch tar xz git binutils

    ## Automake stuff
    pacman $IOPTS automake autoconf pkg-config

    ## Other libs
    pacman $IOPTS $PMPREFIX-$PYINST $PMPREFIX-openssl # libxslt docbook-xml docbook-xsl

    # Install MinGW related stuff
    pacman $IOPTS $PMPREFIX-gcc $PMPREFIX-gmp
    pacman $IOPTS $PMPREFIX-gettext $PMPREFIX-libiconv $PMPREFIX-libtool

    log_status "Installing precompiled devel libraries..."

    # Libraries
    pacman $IOPTS $PMPREFIX-zlib $PMPREFIX-libpng $PMPREFIX-giflib $PMPREFIX-libtiff
    pacman $IOPTS $PMPREFIX-libjpeg-turbo $PMPREFIX-libxml2 $PMPREFIX-freetype
    pacman $IOPTS $PMPREFIX-fontconfig $PMPREFIX-glib2 $PMPREFIX-pixman
    pacman $IOPTS $PMPREFIX-harfbuzz

    touch $PMTEST
    log_note "Finished installing precompiled libraries!"
else
    log_note "Detected that precompiled libraries are already installed."
    log_note "  Delete '$PMTEST' and run this script again if"
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
        
        if [ ! -f "$folder.configure-complete" ] || [ "$opt1" = "--reconfigure" ]; then
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

# install_source(git_link, folder_name, custom_configgen, patchfile, configflags, premakeflags, postmakeflags)
function install_git_source () {
    cd $WORK
    
    log_status "Attempting git install of $2..."
    if [ ! -d "$2" ]; then
        if [ -d "$BASE/work/$MINGOTHER/$2" ]; then
            log_status "Found copy from other arch build, performing local clone..."
            cp -r "$BASE/work/$MINGOTHER/$2" . || bail "Local clone failed"
            cd "$2"
            git clean -dxf || bail "Could not clean repository"
            git reset --hard || bail "Could not reset repository"
        else
            log_status "Cloning git repository from $1..."
            git clone "$1" "$2" || bail "Git clone of $1"
            cd "$2"
        fi
        
        if [ ! -z "$4" ]; then
            log_status "Patching the repository..."
            git apply --ignore-whitespace "$PATCH/$4" || bail "Git patch failed"
        fi
    else
        cd "$2"
        #log_status "Attempting update of git repository..."
        #git pull --rebase || log_note "Failed to update. Unstaged changes?"
    fi
    
    if [ ! -f .gen-configure-complete ]; then
        log_status "Generating configure files..."
        libtoolize -i || bail "Failed to run libtoolize"
        
        if [ ! -z "$3" ]; then
            eval "$3" || bail "Failed to generate makefiles"
        else
            ./autogen.sh || bail "Failed to autogen"
        fi
        touch .gen-configure-complete
    fi
    
    cd ..
    install_source "" "$2" "${@:5}"
    
}

log_status "Installing custom libraries..."
install_git_source "http://github.com/fontforge/libspiro" "libspiro" "autoreconf -i && automake --foreign -Wall"
install_git_source "http://github.com/fontforge/libuninameslist" "libuninameslist" "autoreconf -i && automake --foreign"

# X11 libraries
log_status "Installing X11 libraries..."

xproto=X.Org/proto
xlib=X.Org/lib
xcb=X.Org/xcb

install_git_source "git://anongit.freedesktop.org/xorg/util/macros" "util-macros" 
install_git_source "git://anongit.freedesktop.org/xorg/proto/x11proto" "x11proto" "" "x11proto.patch"
install_git_source "git://anongit.freedesktop.org/xorg/proto/renderproto" "renderproto"
install_git_source "git://anongit.freedesktop.org/xorg/proto/bigreqsproto" "bigreqsproto"
install_git_source "git://anongit.freedesktop.org/xorg/proto/kbproto" "kbproto"
install_git_source "git://anongit.freedesktop.org/xorg/proto/inputproto" "inputproto"
install_git_source "git://anongit.freedesktop.org/xorg/proto/xextproto" "xextproto"
install_git_source "git://anongit.freedesktop.org/xorg/proto/xf86bigfontproto" "xf86bigfontproto"
install_git_source "git://anongit.freedesktop.org/xcb/proto" "xcb-proto"

install_git_source "git://anongit.freedesktop.org/xorg/lib/libXau" "libXau"
install_git_source "git://anongit.freedesktop.org/xorg/lib/libxtrans" "libxtrans" "" "libxtrans.patch"
install_git_source "git://anongit.freedesktop.org/xcb/libxcb" "libxcb" "" "libxcb.patch" \
"
LIBS=-lws2_32
--disable-composite
--disable-damage
--disable-dpms
--disable-dri2
--disable-dri3
--disable-glx
--disable-present
--disable-randr
--disable-record
--disable-resource
--disable-screensaver
--disable-shape
--disable-shm
--disable-sync
--disable-xevie
--disable-xfixes
--disable-xfree86-dri
--disable-xinerama
--disable-xinput
--disable-xprint
--disable-selinux
--disable-xkb
--disable-xtest
--disable-xv
--disable-xvmc
"
install_git_source "git://anongit.freedesktop.org/xorg/lib/libX11" "libX11" "" "libx11.patch"  "--disable-ipv6"
install_git_source "git://anongit.freedesktop.org/xorg/lib/libXext" "libXext" "" "libxext.patch"
install_git_source "git://anongit.freedesktop.org/xorg/lib/libXrender" "libXrender"
install_git_source "git://anongit.freedesktop.org/xorg/lib/libXft" "libXft" "" "libXft.patch"

#While MSYS2 ships with Cairo & Pango, they're not built with X11 support.
log_status "Installing Cairo..."
install_source_patch cairo-1.12.16.tar.xz "" "cairo.patch" "--enable-xlib --enable-xcb --enable-xlib-xcb --enable-xlib-xrender --disable-pdf --disable-svg "

# Download from http://ftp.gnome.org/pub/gnome/sources/pango
log_status "Installing Pango..."
install_source pango-1.36.7.tar.xz "" "--with-xft --with-cairo"

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
        if [ -d "$BASE/work/$MINGOTHER/fontforge" ]; then
            log_status "Found copy from other arch build, performing local clone..."
            # Don't use git clone - need the remotes for updating
            cp -r "$BASE/work/$MINGOTHER/fontforge" . || bail "Local clone failed"
            cd "fontforge"
            git clean -dxf || bail "Could not clean repository"
            git reset --hard || bail "Could not reset repository"
        else
            log_status "Cloning the fontforge repository..."
            git clone https://github.com/jtanx/fontforge || bail "Cloning fontforge"
            cd "fontforge"
        fi
else
    cd "fontforge"
fi

if [ ! -f fontforge.configure-complete ] || [ "$opt1" = "--reconfigure" ]; then
    log_status "Running the configure script..."
    
    if [ ! -f configure ]; then
        log_note "No configure script detected; running ./boostrap..."
        ./bootstrap || bail "FontForge autogen"
    fi

    # libreadline is disabled because it causes issues when used from the command line (e.g Ctrl+C doesn't work)
    # windows-cross-compile to disable check for libuuid
    PYTHON=$PYINST \
    ./configure $HOST \
        --enable-shared \
        --disable-static \
        --enable-windows-cross-compile \
        --datarootdir=/usr/share/share_ff \
        --without-libzmq \
        --with-freetype-source="$WORK/freetype-2.5.3" \
        --without-libreadline \
        || bail "FontForge configure"
    touch fontforge.configure-complete
fi

if [ "$opt1" != "--nomake" ]; then
    log_status "Compiling FontForge..."
    make -j 4	|| bail "FontForge make"

    log_status "Installing FontForge..."
    make -j 4 install || bail "FontForge install"
fi

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
objcopy --only-keep-debug "$ffex" "$DBSYMBOLS/fontforge.debug"
objcopy --add-gnu-debuglink="$DBSYMBOLS/fontforge.debug" "$RELEASE/bin/fontforge.exe"
#cp "$ffex" "$RELEASE/bin/"
log_status "Copying the libraries required by FontForge..."
for f in $fflibs; do
    filename="$(basename $f)"
    filenoext="${filename%.*}"
    strip "$f" -so "$RELEASE/bin/$filename"
    #cp "$f" "$RELEASE/bin/"
    if [ -f "$TARGET/bin/$filename" ]; then
        #Only create debug files for the ones we compiled!
        objcopy --only-keep-debug "$f" "$DBSYMBOLS/$filenoext.debug"
        objcopy --add-gnu-debuglink="$DBSYMBOLS/$filenoext.debug" "$RELEASE/bin/$filename"
    fi
done

log_status "Copying the shared folder of FontForge..."
cp -rf /usr/share/share_ff/fontforge "$RELEASE/share/"
cp -rf /usr/share/share_ff/locale "$RELEASE/share/"
rm -f "$RELEASE/share/prefs"

log_note "Installing custom binaries..."
cd $WORK
#AddToPath.bat: Utility to only add a path to PATH if it's not currently there
#Or maybe not. It's crazy slow if PATH is complex.
#cp "$PATCH/AddToPath.bat" "$RELEASE/bin/"

# potrace - http://potrace.sourceforge.net/#downloading
if [ ! -f $RELEASE/bin/potrace.exe ]; then
    log_status "Installing potrace..."
    mkdir -p potrace
    cd potrace
    
    if [ ! -d $POTRACE_DIR ]; then
        tar axvf $BINARY/$POTRACE_ARC || bail "Potrace not found!"
    fi
    strip $POTRACE_DIR/potrace.exe -so $RELEASE/bin/potrace.exe
    cd ..
fi

#VcXsrv - Xming replacement
if [ ! -d $RELEASE/bin/VcXsrv ]; then
    log_status "Installing VcXsrv..."
    if [ ! -d VcXsrv ]; then
        tar axvf $BINARY/$VCXSRV || bail "VcXsrv not found!"
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
cp -rf $TARGET/lib/pango "$RELEASE/lib"

log_status "Copying UI fonts..."
#Remove the old/outdated Inconsolata/Cantarell from pixmaps
rm "$RELEASE/share/fontforge/pixmaps/"*.ttf > /dev/null 2>&1
rm "$RELEASE/share/fontforge/pixmaps/"*.otf > /dev/null 2>&1
#Copy the fonts
mkdir -p "$RELEASE/share/fonts"
cp "$UIFONTS"/* "$RELEASE/share/fonts/"
if [ -z "$(ls -A "$UIFONTS" 2>&1 | grep -v "\\.txt$")" ]; then
    log_note "No UI fonts specified, copying some standard ones..."
    cp /usr/share/share_ff/fontforge/pixmaps/Cantarell* "$RELEASE/share/fonts"
fi

if [ -f "$PATCH/fontforge.resources" ]; then
    log_status "Copying the custom resource file..."
    cp "$PATCH/fontforge.resources" "$RELEASE/share/fontforge/pixmaps/resources"
fi

log_status "Copying sfd icon..."
cp "$PATCH/artwork/sfd-icon.ico" "$RELEASE/share/fontforge/"

log_status "Copying the Python executable and libraries..."
# Name the python binary to something custom to avoid clobbering any Python installation that the user already has
strip "/$MINGVER/bin/$PYINST.exe" -so "$RELEASE/bin/ffpython.exe"
cd $BASE
if [ -d "$RELEASE/lib/$PYVER" ]; then
    log_note "Skipping python library copy because folder already exists, and copying is slow."
else
    if [ ! -d "$BINARY/$PYVER" ]; then
        log_note "Python folder not found - running 'strip-python'..."
        $BASE/strip-python.sh
    fi
    cp -r "$BINARY/$PYVER" "$RELEASE/lib" || bail "Python folder could not be copied"
fi
cd $WORK

log_status "Stripping Python cache files (*.pyc,*.pyo,__pycache__)..."
find "$RELEASE/lib/$PYVER" -regextype sed -regex ".*\.py[co]" | xargs rm -rfv
find "$RELEASE/lib/$PYVER" -name "__pycache__" | xargs rm -rfv

if [ "$MSYSTEM" = "MINGW32" ]; then
    log_status "Copying OpenSSL libraries (for Python hashlib)..."
    strip /$MINGVER/bin/libeay32.dll -so "$RELEASE/bin/libeay32.dll"
fi

log_status "Copying the Python extension dlls..."
cp -f "$TARGET/lib/$PYVER/site-packages/fontforge.pyd" "$RELEASE/lib/$PYVER/site-packages/" || bail "Couldn't copy pyhook dlls"
cp -f "$TARGET/lib/$PYVER/site-packages/psMat.pyd" "$RELEASE/lib/$PYVER/site-packages/" || bail "Couldn't copy pyhook dlls"

log_status "Generating the version file..."
version_hash=`git -C $WORK/fontforge rev-parse master`
current_date=`date "+%c %z"`
printf "FontForge Windows build ($ARCH)\r\n$version_hash ($current_date)\r\n\r\n" > $RELEASE/VERSION.txt
printf "A copy of the changelog follows.\r\n\r\n" >> $RELEASE/VERSION.txt
cat $RELEASE/CHANGELOG.txt >> $RELEASE/VERSION.txt

# Might as well auto-generate everything
#sed -bi "s/^git .*$/git $version_hash ($current_date).\r/g" $RELEASE/VERSION.txt

log_note "Build complete."















