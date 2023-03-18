#!/bin/sh

set -e
set -x

# Build debug code, else build with no debug, and in release mode.
DEBUG=1

if which ldc2 >/dev/null; then
  OPTS=""
  if [ "${DEBUG}" = 1 ]; then
    OPTS="-d-debug -O1"
  else
    OPTS="-release -O2"
  fi
  time ldc2 ${OPTS} -of=multimonitor_ldc source/*.d
fi
if which dmd >/dev/null; then
  OPTS=""
  if [ "${DEBUG}" = 1 ]; then
    OPTS="-O -debug"
  else
    OPTS="-release -O -inline"
  fi
  time dmd ${OPTS}  -w -de -of=multimonitor_dmd source/*.d
fi
if which gdc >/dev/null; then
  OPTS=""
  if [ "${DEBUG}" = 1 ]; then
    OPTS="-Og -fdebug"
  else
    OPTS="-O2 -frelease -Wno-uninitialized"
  fi
  time gdc ${OPTS} -W -Wno-uninitialized -o multimonitor_gdc source/*.d || true
fi

# Note, currently one of the stages of building (dpkg-deb -x / tar), fails when using sshfs.
# See https://github.com/libfuse/sshfs/issues/250 for details.
mkdir -p AppDir/usr/bin
cp -v multimonitor_ldc AppDir/usr/bin/multimonitor
mkdir -p AppDir/usr/share/icons
cp -v /usr/share/icons/desktop-base/scalable/emblems/emblem-debian.svg AppDir/usr/share/icons/multimonitor.svg
appimage-builder --skip-test
for F in multimonitor-20*-x86_64.AppImage; do
  sha256sum "$F"
  if [ -d "${HOME}/vps4/home/baryluk/public_html/multimonitor" ]; then
    cp --target-directory="${HOME}/vps4/home/baryluk/public_html/multimonitor" "$F"
  fi
fi
