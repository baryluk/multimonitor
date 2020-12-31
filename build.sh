#!/bin/sh

set -e
set -x

if which gdc >/dev/null; then
  # -frelease -Wno-uninitialized
  time gdc -O2 -W -Wno-uninitialized -o multimonitor_gdc *.d
fi
if which ldc2 >/dev/null; then
  # -release
  time ldc2 -O2 -of=multimonitor_ldc *.d
fi
if which dmd >/dev/null; then
  # -release
  time dmd -O -inline -w -de -of=multimonitor_dmd *.d
fi
