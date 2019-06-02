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
depsonly=0

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
    echo "  -l, --depsonly     Only install the dependencies and not FontForge itself."
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

function get_archive() {
    local archive=$1
    local url=$2
    local url2=$3

    if [ ! -f "$archive" ]; then
        log_note "$archive does not exist, downloading from $url"
        wget --tries 4 "$url" -O "$archive" || ([ ! -z "$url2" ] && wget --tries 4 "$url2" -O "$archive")
    fi
}

# Preamble
log_note "MSYS2 FontForge build script..."

# Retrieve input arguments to script
optspec=":hrnydal-:"
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
                depsonly)
                    depsonly=$((1-depsonly)) ;;
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
        l)
            depsonly=$((1-depsonly)) ;;
        y)
            yes=$((1-yes)) ;;
        h)
            dohelp 0 ;;
        *)
            log_error "Unknown argument -${OPTARG}"
            dohelp 1 ;;
    esac
done

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
    POTRACE_DIR="potrace-1.15.win32"
elif [ "$MSYSTEM" = "MINGW64" ]; then
    log_note "Building 64-bit version!"

    ARCHNUM="64"
    MINGVER=mingw64
    MINGOTHER=mingw32
    HOST="--build=x86_64-w64-mingw32 --host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32"
    PMPREFIX="mingw-w64-x86_64"
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
PYINST=python3

# Check for AppVeyor specific settings
if (($appveyor)); then
    yes=1
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

    # TODO remove this; get libuninameslist into the main repo
    if ! grep -q fontforgelibs /etc/pacman.conf; then
        log_note "Adding the fontforgelibs repo..."
        echo -ne "\n[fontforgelibs32]\nServer = https://dl.bintray.com/jtanx/fontforgelibs/fontforgelibs32\n" >> /etc/pacman.conf
        echo -ne "Server = http://downloads.sourceforge.net/project/fontforgebuilds/build-system-extras/fontforgelibs/i686\n" >> /etc/pacman.conf
        echo -ne "[fontforgelibs64]\nServer = https://dl.bintray.com/jtanx/fontforgelibs/fontforgelibs64\n" >> /etc/pacman.conf
        echo -ne "Server = http://downloads.sourceforge.net/project/fontforgebuilds/build-system-extras/fontforgelibs/x86_64\n" >> /etc/pacman.conf
        # This option has the tendency to fail depending on the server it connects to.
        # Retry up to 5 times before falling over.
        for i in {1..5}; do pacman-key -r 90F90C4A && break || sleep 2; done
        pacman-key --lsign-key 90F90C4A || bail "Could not add fontforgelibs signing key"
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

    log_status "Installing precompiled devel libraries..."
    # Libraries
    pacman $IOPTS $PMPREFIX-{libspiro-git,libuninameslist-git} # TODO mainline these
    pacman $IOPTS $PMPREFIX-{zlib,libpng,giflib,libtiff,libjpeg-turbo,libxml2}
    pacman $IOPTS $PMPREFIX-{freetype,fontconfig,glib2,pixman,harfbuzz,woff2,gtk3}

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

PYVER="$(pacman -Qi mingw-w64-i686-${PYINST} | awk '/Version/{print $3}' | cut -d- -f1 | cut -d. -f1-2)"
if [ -z "$PYVER" ]; then
    bail "Failed to infer the installed Python version"
fi
PYVER="python${PYVER}"
log_note "Inferred installed Python version as $PYVER"

log_status "Retrieving supplementary archives (if necessary)"
get_archive "$SOURCE/$FREETYPE_ARCHIVE" \
            "http://download.savannah.gnu.org/releases/freetype/$FREETYPE_ARCHIVE" \
            "https://sourceforge.net/projects/freetype/files/freetype2/${FREETYPE_VERSION}/freetype-${FREETYPE_VERSION}.tar.bz2" || bail "FreeType2 archive retreival"
get_archive "$BINARY/$POTRACE_ARC" "https://dl.bintray.com/jtanx/fontforgelibs/build-system-extras/${POTRACE_ARC}" || bail "Potrace retrieval"

cd $WORK

# run_fontforge, TODO - rethink this, now that gdk is used
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
        $TAR "$SOURCE/$FREETYPE_ARCHIVE"
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
        time ./configure $HOST \
            --enable-static \
            --enable-shared \
            --enable-gdk=gdk3 \
            --datarootdir=/usr/share/share_ff \
            --with-freetype-source="$WORK/$FREETYPE_NAME" \
            --without-libreadline \
            --enable-fontforge-extras \
            --enable-woff2 \
            || bail "FontForge configure"
        touch fontforge.configure-complete
    fi

    log_status "Compiling FontForge..."
    time make -j$(($(nproc)+1)) || bail "FontForge make"

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
        $TAR "$BINARY/$POTRACE_ARC"
    fi
    strip $POTRACE_DIR/potrace.exe -so $RELEASE/bin/potrace.exe
    cd ..
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
        $BASE/strip-python.sh "$PYVER" > /dev/null
    fi
    cp -r "$BINARY/$PYVER" "$RELEASE/lib" || bail "Python folder could not be copied"
fi
cd $WORK

log_status "Stripping Python cache files (*.pyc,*.pyo,__pycache__)..."
find "$RELEASE/lib/$PYVER" -regextype sed -regex ".*\.py[co]" | xargs rm -rfv
find "$RELEASE/lib/$PYVER" -name "__pycache__" | xargs rm -rfv

#if [ "$MSYSTEM" = "MINGW32" ]; then
#    log_status "Copying OpenSSL libraries (for Python hashlib)..."
#    strip /$MINGVER/bin/libeay32.dll -so "$RELEASE/bin/libeay32.dll"
#    strip /$MINGVER/bin/ssleay32.dll -so "$RELEASE/bin/ssleay32.dll"
#fi

log_status "Copying the Python extension dlls..."
cp -f "$TARGET/lib/$PYVER/site-packages/fontforge.pyd" "$RELEASE/lib/$PYVER/site-packages/"  || \
cp -f "/usr/local/lib/python2.7/site-packages/fontforge.pyd" "$RELEASE/lib/$PYVER/site-packages/" || bail "Couldn't copy pyhook dlls"
cp -f "$TARGET/lib/$PYVER/site-packages/psMat.pyd" "$RELEASE/lib/$PYVER/site-packages/" || \
cp -f "/usr/local/lib/python2.7/site-packages/psMat.pyd" "$RELEASE/lib/$PYVER/site-packages/" || bail "Couldn't copy pyhook dlls"

log_status "Generating the version file..."
current_date=`date "+%c %z"`
actual_branch=`git -C $FFPATH rev-parse --abbrev-ref HEAD`
actual_hash=`git -C $FFPATH rev-parse HEAD`
if (($appveyor)); then
    version_hash=`git -C $FFPATH ls-remote origin master | awk '{ printf $1 }'`
else
    version_hash=`git -C $FFPATH rev-parse master`
fi


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

# Might as well auto-generate everything
#sed -bi "s/^git .*$/git $version_hash ($current_date).\r/g" $RELEASE/VERSION.txt

log_note "Build complete."
