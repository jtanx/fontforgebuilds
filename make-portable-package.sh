#!/bin/sh

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

if [ -z "$1" ]; then
    postfix="r1"
else
    postfix="$1"
fi

if [ "$MSYSTEM" = "MINGW32" ]; then
    ARCH="32"
    PKGPREFIX="FontForge-mingw-w64-i686"
else
    ARCH="64"
    PKGPREFIX="FontForge-mingw-w64-x86_64"
fi

MINGVER=mingw$ARCH
BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SETUP=$BASE/fontforge-setup
WORK=$BASE/work/$MINGVER/
RELEASE=$BASE/ReleasePackage/

log_note "Packaging $ARCH-bit release..."
pacman -S --noconfirm --needed p7zip > /dev/null 2>&1 

version_hash=`git -C $WORK/fontforge rev-parse master`
version_hash=${version_hash:0:6}
log_status "Version hash is $version_hash"

filename="$PKGPREFIX-$version_hash-$postfix.7z"
log_status "Name is $filename"

log_status "Building the archive..."
if [ -f "$filename" ]; then
    read -p "File exists. Overwrite? [y/N]: " overwrite
    case $overwrite in
        [Yy]* ) rm -fv "$filename" || bail "Could not remove $filename"; break;;
        * ) bail "Not overwriting $filename." ;;
    esac
fi

wszip="/c/Program Files/7-Zip/7z.exe"
if [ -f "$wszip" ]; then
    szip="$wszip"
else
    szip="7za"
fi

"$szip" a -t7z -mx=9 -m0=lzma2 -md=128m "$filename"  "$RELEASE"/*
