#!/bin/bash
# FontForge build script.
# Uses MSYS2/MinGW-w64
# Author: Jeremy Tan
# This script retrieves and installs all libraries required to build FontForge.
# It then attempts to compile the latest version of FontForge, and to
# subsequently make a redistributable package.

reconfigure=0
nomake=0
yes=0
makedebug=0
appveyor=0
withgdk=0
withoutgdk=0
depsonly=0
depsfromscratch=0
precompiled_pango_cairo=0
releasemode=$(echo "$APPVEYOR_CONFIG_PROD" | sed 's/^$/0/g')

function dohelp() {
    echo "Usage: `basename $0` [options]"
    echo "  -h, --help         Prints this help message"
    echo "  -r, --reconfigure  Forces the configure script to be rerun for the currently"
    echo "                     worked-on package."
    echo "  -n, --nomake       Don't make/make install FontForge but do everything else"
    echo "  -y, --yes          Say yes to all build script prompts"
    echo "  -d, --makedebug    Adds in debugging utilities into the build (adds a gdb"
    echo "                     automation script)"
    echo "  -a, --appveyor     AppVeyor specific settings (in-source build)"
    echo "  -g, --enable-gdk   Build FontForge using the GDK backend."
    echo "  --disable-gdk      Build FontForge without the GDK backend."
    echo "  -l, --depsonly     Only install the dependencies and not FontForge itself."
    echo "  -s, --depsfromscratch Builds all X11 libraries, libspiro and libuninameslist"
    echo "                        from source. Useful only for debugging these libraries."
    echo "  -p, --precompiled-pango-cairo Use the precompiled versions of Pango and"
    echo "                                Cairo that have X11 support. Not recommended"
    echo "                                unless you use MSYS2 only for building"
    echo "                                FontForge and nothing else."
    echo "  -e, --release      Release mode build (enables gnulib patch)"
    exit $1
}

# Colourful text
# Red text
function log_error() {
    echo -ne "\e[31m"; echo "$@"; echo -ne "\e[0m"
}

# Yellow text
function log_status() {
    echo -ne "\e[33m"; echo "$@"; echo -ne "\e[0m"
}

# Green text
function log_note() {
    echo -ne "\e[32m"; echo "$@"; echo -ne "\e[0m"
}

function bail () {
    echo -ne "\e[31m\e[1m"; echo "!!! Build failed at: ${@}"; echo -ne "\e[0m"
    exit 1
}

function detect_arch_switch () {
    local from=".building-$1"
    local to=".building-$2"

    if [ -f "$from" ]; then
        if (($yes)); then
            git clean -dxf "$RELEASE" || bail "Could not reset ReleasePackage"
        else
            read -p "Architecture change detected! ReleasePackage must be reset. Continue? [y/N]: " arch_confirm
            case $arch_confirm in
                [Yy]* )
                    git clean -dxf "$RELEASE" || bail "Could not reset ReleasePackage"
                    rm -rf "$DBSYMBOLS"
                    mkdir -p "$DBSYMBOLS"
                    ;;
                * ) bail "Not overwriting ReleasePackage" ;;
            esac
        fi
    fi

    rm -f $from
    touch $to
}

# Preamble
log_note "MSYS2 FontForge build script..."

# Retrieve input arguments to script
optspec=":hrnydaglsp-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                reconfigure)
                    reconfigure=$((1-reconfigure)) ;;
                nomake)
                    nomake=$((1-nomake)) ;;
                makedebug)
                    makedebug=$((1-makedebug)) ;;
                appveyor)
                    appveyor=$((1-appveyor)) ;;
                enable-gdk)
                    withgdk=$((1-withgdk))
                    if (($withgdk)); then
                        BACKEND_OPT=--enable-gdk
                    else
                        unset BACKEND_OPT
                    fi ;;
                enable-gdk=gdk2)
                    BACKEND_OPT=--enable-gdk=gdk2
                    withgdk=1 ;;
                enable-gdk=gdk3)
                    BACKEND_OPT=--enable-gdk=gdk3
                    withgdk=1 ;;
                disable-gdk)
                    withoutgdk=$((1-withoutgdk)) ;;
                depsonly)
                    depsonly=$((1-depsonly)) ;;
                depsfromscratch)
                    depsfromscratch=$((1-depsfromscratch)) ;;
                precompiled-pango-cairo)
                    precompiled_pango_cairo=$((1-precompiled_pango_cairo)) ;;
                release)
                    releasemode=$((1-releasemode)) ;;
                yes)
                    yes=$((1-yes)) ;;
                help)
                    dohelp 0;;
                *)
                    log_error "Unknown option --${OPTARG}"
                    dohelp 1 ;;
            esac;;
        r)
            reconfigure=$((1-reconfigure)) ;;
        n)
            nomake=$((1-nomake)) ;;
        d)
            makedebug=$((1-makedebug)) ;;
        a)
            appveyor=$((1-appveyor)) ;;
        g)
            withgdk=$((1-withgdk)) ;;
        l)
            depsonly=$((1-depsonly)) ;;
        s)
            depsfromscratch=$((1-depsfromscratch)) ;;
        p)
            precompiled_pango_cairo=$((1-precompiled_pango_cairo)) ;;
        e)
            releasemode=$((1-releasemode)) ;;
        y)
            yes=$((1-yes)) ;;
        h)
            dohelp 0 ;;
        *)
            log_error "Unknown argument -${OPTARG}"
            dohelp 1 ;;
    esac
done

# Force GDK building if we've previously set it unless explicitly stated not to
[ -f ".building-gdk" ] && withgdk=1
if (($withoutgdk)) || (( ! $withgdk )); then
    log_status "Building without the GDK backend (using X11 instead)."
    withgdk=0
    rm -f ".building-gdk"
elif (($withgdk)); then
    log_status "Building with the GDK backend - remove the file .building-gdk or pass --disable-gdk to disable."
    if [ -z "$BACKEND_OPT" ]; then
        BACKEND_OPT=`cat .building-gdk`
        if [ -z "$BACKEND_OPT" ]; then
            log_error ".building-gdk was empty, assuming --enable-gdk as GDK build flag!"
            BACKEND_OPT=--enable-gdk
            echo $BACKEND_OPT > .building-gdk
        fi
    else
        echo $BACKEND_OPT > .building-gdk
    fi
    log_status "GDK Build flag: $BACKEND_OPT"
fi

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

    ARCHNUM="32"
    MINGVER=mingw32
    MINGOTHER=mingw64
    HOST="--build=i686-w64-mingw32 --host=i686-w64-mingw32 --target=i686-w64-mingw32"
    PMPREFIX="mingw-w64-i686"
    PYINST=python2
    PYVER=python2.7
    VCXSRV="VcXsrv-1.14.2-minimal.tar.xz"
    POTRACE_DIR="potrace-1.15.win32"
elif [ "$MSYSTEM" = "MINGW64" ]; then
    log_note "Building 64-bit version!"

    ARCHNUM="64"
    MINGVER=mingw64
    MINGOTHER=mingw32
    HOST="--build=x86_64-w64-mingw32 --host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32"
    PMPREFIX="mingw-w64-x86_64"
    PYINST=python3
    PYVER=python3.6
    VCXSRV="VcXsrv-1.17.0.0-x86_64-minimal.tar.xz"
    POTRACE_DIR="potrace-1.15.win64"
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

# Check for AppVeyor specific settings
if (($appveyor)); then
    yes=1
    depsfromscratch=0
    precompiled_pango_cairo=1
    FFPATH=`cygpath -m $APPVEYOR_BUILD_FOLDER`
    TAR="tar axf"
    export PYTHONHOME=/$MINGVER
else
    FFPATH=$WORK/fontforge
    TAR="tar axvf"
fi

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
export ACLOCAL_PATH="m4:$TARGET/share/aclocal:/$MINGVER/share/aclocal"
export ACLOCAL="/bin/aclocal"
export M4="/bin/m4"
# Compiler flags
export LDFLAGS="-L$TARGET/lib -L/$MINGVER/lib -L/usr/local/lib -L/lib"
export CFLAGS="-DWIN32 -I$TARGET/include -I/$MINGVER/include -I/usr/local/include -I/include -g"
export CPPFLAGS="${CFLAGS}"
export LIBS=""

# Install all the available precompiled binaries
if (( ! $nomake )) && [ ! -f $PMTEST ]; then
    log_status "First time run; installing MSYS and MinGW libraries..."
    if (( ! $depsfromscratch )) || (($precompiled_pango_cairo)); then
        if ! grep -q fontforgelibs /etc/pacman.conf; then
            log_note "Adding the fontforgelibs repo..."
            echo -ne "\n[fontforgelibs32]\nServer = https://dl.bintray.com/jtanx/fontforgelibs/fontforgelibs32\n" >> /etc/pacman.conf
            echo -ne "Server = http://downloads.sourceforge.net/project/fontforgebuilds/build-system-extras/fontforgelibs/i686\n" >> /etc/pacman.conf
            echo -ne "[fontforgelibs64]\nServer = https://dl.bintray.com/jtanx/fontforgelibs/fontforgelibs64\n" >> /etc/pacman.conf
            echo -ne "Server = http://downloads.sourceforge.net/project/fontforgebuilds/build-system-extras/fontforgelibs/x86_64\n" >> /etc/pacman.conf
            # This option has the tendency to fail depending on the server it connects to.
            # Retry up to 5 times before falling over.
            for i in {1..5}; do pacman-key -r 90F90C4A && break || sleep 1; done
            pacman-key --lsign-key 90F90C4A || bail "Could not add fontforgelibs signing key"
        fi
    fi
    pacman -Sy --noconfirm

    IOPTS="-S --noconfirm --needed"

    if (( ! $appveyor )); then
        # Install the base MSYS packages needed
        pacman $IOPTS diffutils findutils make patch tar automake autoconf pkg-config

        # Install MinGW related stuff
        pacman $IOPTS $PMPREFIX-{gcc,gmp,ntldd-git,gettext,libiconv,libtool}
    else
        # Upgrade gcc
        pacman $IOPTS --force --nodeps $PMPREFIX-{gcc,gcc-libs}
        pacman $IOPTS $PMPREFIX-{ntldd-git,gettext,libiconv,libtool}
    fi

    ## Other libs
    pacman $IOPTS $PMPREFIX-{$PYINST,openssl}

    if (( ! $withgdk )); then
        if (($precompiled_pango_cairo)); then
            log_note "Installing precompiled Pango and Cairo libraries..."
            pacman $IOPTS --force $PMPREFIX-{cairo-x11,pango-x11} || \
            bail "Install Pango/Cairo dependencies manually"
        else
            log_note "Installing vanilla Pango and Cairo libraries..."
            pacman $IOPTS $PMPREFIX-{cairo,pango} || \
            bail "Install Pango/Cairo dependencies manually"
        fi

        if (( ! $depsfromscratch )); then
            log_note "Installing precompiled X11..."
            pacman $IOPTS --force $PMPREFIX-{libx11-git,libxext-git}
            pacman $IOPTS $PMPREFIX-{libxrender-git,libxft-git}
        fi
    fi

    if (( ! $depsfromscratch )); then
        log_note "Installing precompiled libspiro and libuninameslist..."
        pacman $IOPTS $PMPREFIX-{libspiro-git,libuninameslist-git}
    fi

    log_status "Installing precompiled devel libraries..."

    # Libraries
    pacman $IOPTS $PMPREFIX-{zlib,libpng,giflib,libtiff,libjpeg-turbo,libxml2}
    pacman $IOPTS $PMPREFIX-{freetype,fontconfig,glib2,pixman,harfbuzz,woff2}

    if (($withgdk)); then
        if [[ $BACKEND_OPT == *"gdk2"* ]]; then
            pacman $IOPTS $PMPREFIX-gtk2
        else
            pacman $IOPTS $PMPREFIX-gtk3
        fi
    fi

    touch $PMTEST
    log_note "Finished installing precompiled libraries!"
else
    log_note "Detected that precompiled libraries are already installed."
    log_note "  Delete '$PMTEST' and run this script again if"
    log_note "  this is not the case."
fi # pacman installed

FREETYPE_VERSION="$(pacman -Qi $PMPREFIX-freetype | awk '/Version/{print $3}' | cut -d- -f1)"
FREETYPE_NAME="freetype-${FREETYPE_VERSION}"
FREETYPE_ARCHIVE="${FREETYPE_NAME}.tar.bz2"

if [ -z "$FREETYPE_VERSION" ]; then
    bail "Failed to infer the installed FreeType version"
fi

log_note "Inferred installed FreeType version as $FREETYPE_VERSION"

function get_archive() {
    local archive=$1
    local url=$2
    local url2=$3

    if [ ! -f "$archive" ]; then
        log_note "$archive does not exist, downloading from $url"
        wget --tries 4 "$url" -O "$archive" || [ ! -z "$url2" ] && wget --tries 4 "$url2" -O "$archive"
    fi

    log_note "Extracting from $archive"
    $TAR "$archive"
}

# Install from tarball
# install_source_raw(file, folder_name, patch, custom_configgen, configflags, premakeflags, postmakeflags)
function install_source_patch () {
    local file=$1
    local folder=$2
    local patch=$3
    local configgen=$4
    local configflags=$5
    local premakeflags=$6
    local postmakeflags=$7

    # Default to the name of the archive, if folder name is not given
    if [ -z "$folder" ]; then
        local filename="$(basename $1)"
        folder="${filename%.tar*}"
    fi

    cd $WORK
    if [ ! -f "$folder/$folder.complete"  ]; then
        log_status "Installing $folder..."
        if [ ! -d "$folder" ]; then
            $TAR $SOURCE$file || bail "$folder"
        else
            log_note "Sensing incomplete build, re-attempting the build..."
        fi

        cd $folder || bail "$folder"
        if [ ! -z "$patch" ]; then
            log_status "Patching $folder with $patch..."
            # Check if it's already been applied or not
            patch -p1 -N --dry-run --silent < $PATCH/$patch 2>/dev/null
            if [ $? -eq 0 ]; then
                patch -p1 < $PATCH/$patch || bail "$folder"
            else
                log_note "Sensed that patch has already been applied; skipping"
            fi
        fi

        if [ ! -z "$configgen" ] && [ ! -f "$folder.configgen-complete" ]; then
            log_status "Running the config generation script..."
            eval "$configgen" || bail "Config generation failed"
            touch "$folder.configgen-complete"
        fi

        if [ ! -f "$folder.configure-complete" ] || (($reconfigure)); then
            log_status "Running the configure script..."
            ./configure $HOST $configflags || bail "$folder"
            touch "$folder.configure-complete"
        else
            log_note "Sensed that the configure script has already run; delete $folder.configure-complete to rerun configure"
        fi
        cmd="$premakeflags make -j$(($(nproc)+1)) $postmakeflags || bail '$folder'"
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
    install_source_patch "$1" "$2" "" "" "${@:3}"
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
    else
        cd "$2"
        #log_status "Attempting update of git repository..."
        #git pull --rebase || log_note "Failed to update. Unstaged changes?"
    fi

    if [ ! -z "$4" ]; then
        #Just a bit too verbose
        #log_status "Checking if the patch needs to be applied..."
        git apply --check --ignore-whitespace "$PATCH/$4" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_status "Patching the repository..."
            git apply --ignore-whitespace "$PATCH/$4" || bail "Git patch failed"
            log_note "Patch applied."
        #else
        #    log_note "Patch already applied or not applicable. Continuing..."
        fi
    fi

    #patch -p1 -N --dry-run --silent < $PATCH/$patch 2>/dev/null

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

if (($depsfromscratch)); then
    log_status "Installing custom libraries..."
    install_git_source "http://github.com/fontforge/libspiro" "libspiro" "autoreconf -i && automake --foreign -Wall"
    install_git_source "http://github.com/fontforge/libuninameslist" "libuninameslist" "autoreconf -i && automake --foreign"
fi

if (($depsfromscratch)) && (( ! $withgdk )); then
    # X11 libraries
    log_status "Installing X11 libraries..."

    install_git_source "git://anongit.freedesktop.org/xorg/util/macros" "util-macros"
    install_git_source "git://anongit.freedesktop.org/xorg/proto/x11proto" "x11proto" "" "x11proto.patch"
    install_git_source "git://anongit.freedesktop.org/xorg/proto/renderproto" "renderproto"
    install_git_source "git://anongit.freedesktop.org/xorg/proto/kbproto" "kbproto"
    install_git_source "git://anongit.freedesktop.org/xorg/proto/inputproto" "inputproto"
    install_git_source "git://anongit.freedesktop.org/xorg/proto/xextproto" "xextproto"
    install_git_source "git://anongit.freedesktop.org/xorg/proto/xf86bigfontproto" "xf86bigfontproto"
    install_git_source "git://anongit.freedesktop.org/xcb/proto" "xcb-proto"

    install_git_source "git://anongit.freedesktop.org/xorg/lib/libXau" "libXau"
    install_git_source "git://anongit.freedesktop.org/xorg/lib/libxtrans" "libxtrans" "" "libxtrans.patch"
    LIBS="-lws2_32" install_git_source "git://anongit.freedesktop.org/xcb/libxcb" "libxcb" "" "libxcb.patch" \
    "
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
    install_git_source "git://anongit.freedesktop.org/xorg/lib/libX11" "libX11" "" "libx11.patch"  "--disable-ipv6 --enable-xlocaledir"
    install_git_source "git://anongit.freedesktop.org/xorg/lib/libXext" "libXext" "" "libxext.patch"
    install_git_source "git://anongit.freedesktop.org/xorg/lib/libXrender" "libXrender"
    install_git_source "git://anongit.freedesktop.org/xorg/lib/libXft" "libXft" "" "libXft.patch"
fi

#While MSYS2 ships with Cairo & Pango, they're not built with X11 support.
if (( ! $nomake )) && (( ! $precompiled_pango_cairo )) && (( ! $withgdk )); then
    log_status "Installing Cairo..."
    #Workaround for MSYS2 mingw-w64 removing ctime_r from pthread.h
    install_source_patch cairo-1.15.6.tar.xz "" "cairo.patch" "autoreconf -fiv" "CFLAGS=-D_POSIX --enable-xlib --enable-xcb --enable-xlib-xcb --enable-xlib-xrender --disable-xcb-shm --disable-pdf --disable-svg "

    # Download from http://ftp.gnome.org/pub/gnome/sources/pango
    log_status "Installing Pango..."
    install_source pango-1.40.7.tar.xz "" "--with-xft --with-cairo"

    #log_status "Installing Gtk..."
    #install_source gtk+-3.20.2.tar.xz "" "--enable-win32-backend --enable-shared --enable-introspection --enable-broadway-backend --disable-cups --disable-x11-backend --with-included-immodules --enable-silent-rules"
    #install_source gtk+-2.24.30.tar.xz "" "--enable-win32-backend --enable-shared --enable-introspection --enable-broadway-backend --disable-cups --disable-x11-backend --with-included-immodules --enable-silent-rules"
fi

cd $WORK

# ZMQ does not work for now
#install_git_source "https://github.com/jedisct1/libsodium" "libsodium" "libtoolize -i && ./autogen.sh"
#install_git_source "https://github.com/zeromq/libzmq" "libzmq" "libtoolize -i && ./autogen.sh"
#install_git_source "https://github.com/zeromq/czmq" "czmq" "libtoolize -i && ./autogen.sh"


# VcXsrv_util
if (( ! $withgdk )) && [ ! -f VcXsrv_util/VcXsrv_util.complete ]; then
    log_status "Building VcXsrv_util..."
    mkdir -p VcXsrv_util
    cd VcXsrv_util
    gcc -Wall -Werror -pedantic -std=c99 -O2 -municode -shared-libgcc \
        -o VcXsrv_util.exe "$PATCH/VcXsrv_util.c" \
    || bail "VcXsrv_util"
    touch VcXsrv_util.complete
    cd ..
fi

# run_fontforge
if [ ! -f run_fontforge/run_fontforge.complete ]; then
    log_status "Building run_fontforge..."
    mkdir -p run_fontforge
    cd run_fontforge
    windres "$PATCH/run_fontforge.rc" -O coff -o run_fontforge.res
    gcc -Wall -Werror -pedantic -std=c99 -O2 -mwindows -municode -o run_fontforge.exe "$PATCH/run_fontforge.c" run_fontforge.res \
    || bail "run_fontforge"
    touch run_fontforge.complete
    cd ..
fi


if (($depsonly)); then
    log_note "Installation of dependencies complete."
    exit 0
fi

if (( ! $nomake )); then
    # For the source only; to enable the debugger in FontForge
    if [ ! -d $FREETYPE_NAME ]; then
        log_status "Extracting the FreeType $FREETYPE_VERSION source..."
        get_archive "$SOURCE/$FREETYPE_ARCHIVE" \
            "http://download.savannah.gnu.org/releases/freetype/$FREETYPE_ARCHIVE" \
            "https://sourceforge.net/projects/freetype/files/freetype2/${FREETYPE_VERSION}/freetype-${FREETYPE_VERSION}.tar.bz2" || bail "FreeType2 extraction"
    fi

    log_status "Finished installing prerequisites, attempting to install FontForge!"
    # fontforge
    if (( ! $appveyor )) && [ ! -d fontforge ]; then
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
        cd "$FFPATH";
    fi

    # Patch gnulib to fix 64-bit builds and to add Unicode fopen/open support.
    if [ ! -d gnulib ]; then
        log_status "Cloning gnulib..."
        git clone --depth 10 https://github.com/coreutils/gnulib || \
            git clone git://git.sv.gnu.org/gnulib || bail "Cloning gnulib"
    fi

    if (($releasemode)); then
        log_status "Checking if gnulib should be patched..."
        git -C gnulib apply --check --ignore-whitespace "$PATCH/gnulib.patch" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_note "Patching gnulib..."
            git -C gnulib apply --ignore-whitespace "$PATCH/gnulib.patch" || bail "Git patch failed"
            rm -f fontforge.configure-complete configure
            log_note "Patch applied."
        elif (($appveyor)); then
            bail "Could not patch gnulib from a CI build, is the patch up to date?"
        else
            log_note "gnulib appears to already be patched"
        fi
    fi

    if [ ! -f fontforge.configure-complete ] || (($reconfigure)); then
        log_status "Running the configure script..."

        if [ ! -f configure ]; then
            log_note "No configure script detected; running ./boostrap..."
            ./bootstrap --force || bail "FontForge autogen"
        fi

        # libreadline is disabled because it causes issues when used from the command line (e.g Ctrl+C doesn't work)
        # windows-cross-compile to disable check for libuuid
        #CFLAGS="${CFLAGS} -specs=$BASE/msvcr100.spec" \
        #LIBS="${LIBS} -lmsvcr100" \

        # gdi32 linking is needed for AddFontResourceEx
        LIBS="${LIBS} -lgdi32" \
        PYTHON=$PYINST \
        ./configure $HOST \
            --enable-static \
            --enable-shared \
            $BACKEND_OPT \
            --datarootdir=/usr/share/share_ff \
            --without-libzmq \
            --with-freetype-source="$WORK/$FREETYPE_NAME" \
            --without-libreadline \
            --enable-fontforge-extras \
            --enable-woff2 \
            || bail "FontForge configure"
        touch fontforge.configure-complete
    fi

    log_status "Compiling FontForge..."
    make -j$(($(nproc)+1))	|| bail "FontForge make"

    if (($appveyor)); then
        log_status "Running the test suite..."
        make check -j$(($(nproc)+1)) || bail "FontForge check"
    fi

    log_status "Installing FontForge..."
    make -j$(($(nproc)+1)) install || bail "FontForge install"

    #cd gdraw || bail "cd gdraw"
    #make -j$(($(nproc)+1))	|| bail "FontForge make"
    #make install || bail "Gdraw install"
    #cp "$TARGET/bin/libgdraw-5.dll" "$RELEASE/bin" || bail "Gdraw copy"
    #log_note "DONE"
    #exit
fi

log_status "Assembling the release package..."
ffex=`which fontforge.exe`
MSYSROOT=`cygpath -w /`
FFEXROOT=`cygpath -w $(dirname "${ffex}")`
log_note "The executable: $ffex"
log_note "MSYS root: $MSYSROOT"
log_note "FFEX root: $FFEXROOT"

fflibs=`ntldd -D "$(dirname \"${ffex}\")" -R "$ffex" \
| grep dll \
| sed -e '/^[^\t]/ d'  \
| sed -e 's/\t//'  \
| sed -e 's/.*=..//'  \
| sed -e 's/ (0.*)//' \
| grep -F -e "$MSYSROOT" -e "$FFEXROOT" \
`

log_status "Copying the FontForge executable..."
#strip "$ffex" -so "$RELEASE/bin/fontforge.exe"
cp "$ffex" "$RELEASE/bin/fontforge.exe"
objcopy --only-keep-debug "$ffex" "$DBSYMBOLS/fontforge.debug"
objcopy --add-gnu-debuglink="$DBSYMBOLS/fontforge.debug" "$RELEASE/bin/fontforge.exe"
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

log_status "Copying glib spawn helpers..."
strip "/$MINGVER/bin/gspawn-win$ARCHNUM-helper.exe" -so "$RELEASE/bin/gspawn-win$ARCHNUM-helper.exe" || bail "Glib spawn helper not found!"
strip "/$MINGVER/bin/gspawn-win$ARCHNUM-helper-console.exe" -so "$RELEASE/bin/gspawn-win$ARCHNUM-helper-console.exe" || bail "Glib spawn helper not found!"

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
        get_archive "$BINARY/$POTRACE_ARC" "https://dl.bintray.com/jtanx/fontforgelibs/build-system-extras/${POTRACE_ARC}" || bail "Potrace retrieval"
    fi
    strip $POTRACE_DIR/potrace.exe -so $RELEASE/bin/potrace.exe
    cd ..
fi

if (( ! $withgdk )); then
    #VcXsrv - Xming replacement
    if [ ! -d $RELEASE/bin/VcXsrv ]; then
        log_status "Installing VcXsrv..."
        if [ ! -d VcXsrv ]; then
            get_archive "$BINARY/$VCXSRV" "https://dl.bintray.com/jtanx/fontforgelibs/build-system-extras/${VCXSRV}" || bail "VcXsrv retrieval"
        fi
        cp -rf VcXsrv $RELEASE/bin/
    fi

    log_status "Installing VcXsrv_util..."
    strip $WORK/VcXsrv_util/VcXsrv_util.exe -so "$RELEASE/bin/VcxSrv_util.exe" \
        || bail "VcxSrv_util"
fi

log_status "Installing run_fontforge..."
objcopy -S --file-alignment 1024 $WORK/run_fontforge/run_fontforge.exe "$RELEASE/run_fontforge.exe" \
    || bail "run_fontforge"

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
        $BASE/strip-python.sh > /dev/null
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
    strip /$MINGVER/bin/ssleay32.dll -so "$RELEASE/bin/ssleay32.dll"
fi

log_status "Copying the Python extension dlls..."
cp -f "$TARGET/lib/$PYVER/site-packages/fontforge.pyd" "$RELEASE/lib/$PYVER/site-packages/"  || \
cp -f "/usr/local/lib/python2.7/site-packages/fontforge.pyd" "$RELEASE/lib/$PYVER/site-packages/" || bail "Couldn't copy pyhook dlls"
cp -f "$TARGET/lib/$PYVER/site-packages/psMat.pyd" "$RELEASE/lib/$PYVER/site-packages/" || \
cp -f "/usr/local/lib/python2.7/site-packages/psMat.pyd" "$RELEASE/lib/$PYVER/site-packages/" || bail "Couldn't copy pyhook dlls"

log_status "Generating the version file..."
actual_branch=`git -C $FFPATH rev-parse --abbrev-ref HEAD`
actual_hash=`git -C $FFPATH rev-parse HEAD`
version_hash=`git -C $FFPATH rev-parse master`
current_date=`date "+%c %z"`
printf "FontForge Windows build ($ARCHNUM-bit)\r\n$current_date\r\n$actual_hash [$actual_branch]\r\nBased on master: $version_hash\r\n\r\n" > $RELEASE/VERSION.txt
printf "A copy of the changelog follows.\r\n\r\n" >> $RELEASE/VERSION.txt
cat $RELEASE/CHANGELOG.txt >> $RELEASE/VERSION.txt

if (($makedebug)); then
    log_note "Adding in debugging utilities..."
    cp -f "$PATCH/ffdebugscript.txt" "$RELEASE/" || bail "Couldn't copy debug script"
    cp -f "$PATCH/fontforge-debug.bat" "$RELEASE/" || bail "Couldn't copy fontforge-debug.bat"
    cp -f "$BINARY/gdb-$ARCHNUM.exe" "$RELEASE/bin/gdb.exe" || bail "Couldn't copy GDB"
    cp -f "$BINARY/wtee.exe" "$RELEASE/bin/" || bail "Couldn't copy wtee"
    cp -rf "$DBSYMBOLS" "$RELEASE/bin/" || bail "Couldn't copy debugging symbols"
fi

if (($appveyor)) && (($releasemode)); then
    cd "$BASE/fontforge-setup"
    iscc -Qp fontforgesetup.iss
fi

# Might as well auto-generate everything
#sed -bi "s/^git .*$/git $version_hash ($current_date).\r/g" $RELEASE/VERSION.txt

log_note "Build complete."
