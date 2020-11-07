#!/bin/sh
# Copies the Python Lib directory and strips it down to a reasonable size.
# FontForge essentially ships with its own version of Python

set -eo pipefail

export LC_ALL=C

if [ "$MSYSTEM" == "MINGW32" ]; then
    PACKAGE=mingw-w64-i686-python3
else
    PACKAGE=mingw-w64-x86_64-python3
fi

PYNAME=$(pacman -Qi $PACKAGE | grep -m1 Name | cut -d':' -f2 | xargs)
PYFULLVER=$(pacman -Qi $PACKAGE | grep -m1 Version | cut -d':' -f2 | xargs)
PYVER=python$(echo $PYFULLVER | cut -d. -f1-2)
PYARCH=$(ls -1 "/var/cache/pacman/pkg/$PYNAME-$PYFULLVER-any.pkg.tar."* | head -n1)

cd original-archives/binaries || exit 1

echo "Python: $PYNAME $PYFULLVER ($PYVER): $PYARCH"

if [ ! -d $PYVER ]; then
    tar axf "/var/cache/pacman/pkg/$PYNAME-$PYFULLVER-any.pkg.tar."* --strip-components=2 --wildcards '*/lib/python3.*'
fi

cd $PYVER
rm -rfv "config-${PYVER}" idlelib test turtledemo config
find . -regextype sed -regex ".*\.py[co]" | xargs rm -rfv
find . -name __pycache__ | xargs rm -rfv
