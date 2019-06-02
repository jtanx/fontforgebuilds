#!/bin/sh
# Copies the Python Lib directory and strips it down to a reasonable size.
# FontForge essentially ships with its own version of Python


PYVER="$1"
PYDIR=/$MSYSTEM/lib/$PYVER

if [ -z "$PYVER" ]; then
    echo "Usage: $0 python-version"
    exit 1
fi

cd original-archives/binaries || exit 1

if [ ! -d $PYVER ]; then
	cp -r $PYDIR . || exit 1
fi

cd $PYVER
rm -rfv config-3.4m idlelib test turtledemo config
find . -regextype sed -regex ".*\.py[co]" | xargs rm -rfv
find . -name __pycache__ | xargs rm -rfv
find . -name test | xargs rm -rfv
find . -name tests | xargs rm -rfv
cd ..

cd ../..
