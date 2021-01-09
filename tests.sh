#!/bin/sh

set -e
set -x

MM=./multimonitor_ldc

sleep 3600 &
PIDA=$!
trap "kill -9 $PIDA || true" EXIT
sleep 3600 &
PIDB=$!
trap "kill -9 $PIDA $PIDB || true" EXIT
sleep 3600 &
PIDC=$!
trap "kill -9 $PIDA $PIDB $PIDC || true" EXIT
stress-ng --cpu 1 --timeout 3600s &
PIDD=$!
trap "kill -9 $PIDA $PIDB $PIDC $PIDD || true" EXIT
sleep 5
PIDE=$(pidof stress-ng-cpu)
trap "kill -9 $PIDA $PIDB $PIDC $PIDD $PIDE || true" EXIT

# TODO(baryluk): Spawn some processes with known CPU and Memory behaviour.

# Do a complex test first, so it catches quickly a lot of issues.
"${MM}" --interval_msec=100 --duration_sec=4 \
  --sub "exec sleep 2" \
  --sub "exec sleep 20" \
  --pipe "while sleep 1; do echo \"\$(date '+P_%s.%N')\"; done" \
  --exec "date '+S_%s.%N'" \
  --exec_async "date '+A_%s.%N'" \
  --async_delay_msec=500 \
  --pid $PIDA --pid $PIDE --pids "$PIDA,$PIDB,$PIDC"


# Help tests.
"${MM}" 2>&1 | grep "^Multimonitor - sample information about system and processes" >/dev/null
"${MM}" --help | grep "^Multimonitor - sample information about system and processes" >/dev/null
"${MM}" -h | grep "^Multimonitor - sample information about system and processes" >/dev/null

# No monitor, just timestamps until duration.
"${MM}" --duration_sec=2
"${MM}" --interval_msec=1000  --duration_sec=2

# Monitor process by pids.
"${MM}" --interval_msec=1000  --duration_sec=2 --pids $PIDE
# Monitor process by pid.
"${MM}" --interval_msec=1000  --duration_sec=2 --pid $PIDE
# Monitor process by name.
"${MM}" --interval_msec=1000  --duration_sec=2 --process "stress-ng-cpu"

# Monitor same process one by pid, and one by name.
"${MM}" --interval_msec=1000  --duration_sec=2 --pid $PIDA --process "stress-ng-cpu"

# Monitor same process many times, in multiple ways.
"${MM}" --interval_msec=1000  --duration_sec=2 --pids $PIDA,$PIDB,$PIDA,$PIDD,$PIDE --pid $PIDA --pid $PIDA --pid $PIDE

# ISO 8601
"${MM}" --interval_msec=1000  --duration_sec=2 --pids $PIDE --utc_nice

# Human unfriently and human friendly.
"${MM}" --interval_msec=1000  --duration_sec=2 --pids $PIDE --human_friendly=false
"${MM}" --interval_msec=1000  --duration_sec=2 --pids $PIDE --human_friendly=true

# Buffer output.
"${MM}" --interval_msec=1000  --duration_sec=2 --pids $PIDE --buffered
"${MM}" --interval_msec=1000  --duration_sec=2 --pids $PIDE --buffered --human_friendly=false


# No monitor. Just timestamps, until duration.
"${MM}" --interval_msec=1000  --duration_sec=3
"${MM}" --interval_msec=10    --duration_sec=2

# GPU stuff.
"${MM}" --gpu=min --interval_msec=1000  --duration_sec=3
"${MM}" --gpu=min --interval_msec=10  --duration_sec=2
"${MM}" --duration_sec=2 --gpu=min

# One sync.
"${MM}" --interval_msec=100 --duration_sec=2 --exec "date +S1_%s.%N"
# Two sync.
"${MM}" --interval_msec=100 --duration_sec=2 --exec "date +S1_%s.%N" --exec "date +S2_%s.%N"

# Sync and async.
"${MM}" --interval_msec=100 --duration_sec=2 --exec "date +S1_%s.%N" --exec_async "date +A1_%s.%N"
# Sync and two async.
"${MM}" --interval_msec=100 --duration_sec=2 --exec "date +S1_%s.%N" --exec_async "date +A1_%s.%N" --exec_async "date +A2_%s.%N"
# Sync and async, with slow updates.
"${MM}" --interval_msec=100 --duration_sec=2 --exec "date +S1_%s.%N" --exec_async "date +A1_%s.%N" --async_delay_msec=1000


# Slow async.
"${MM}" --interval_msec=100 --duration_sec=5 --exec "date +S1_%s.%N" --exec_async "sleep 1; date +A1_%s.%N" --async_delay_msec=200

# Slow sync.
"${MM}" --interval_msec=100 --duration_sec=5 --exec "sleep 1; date +S1_%s.%N"

# Sub process, ending after end of duration.
"${MM}" --interval_msec=100 --duration_sec=2 --sub "exec sleep 10"
# Sub process, ending before end of duration.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 2"

# Two sub-processes, one ending before duration, one ending after duration.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 2" --sub "exec sleep 20"

# Pipe that starts producing with a delay
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 2" --sub "exec sleep 20" --pipe "while sleep 1; do echo \"\$(date +P_%s.%N)\"; done"

# Pipe that starts producing immedietly
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 2" --sub "exec sleep 20" --pipe "while true; do echo \"\$(date +P_%s.%N)\"; sleep 1; done"

# Slow pipe producer, but trying to consume fast in async wrapper, faster than interval.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 2" --sub "exec sleep 20" --async_delay_msec=5 --pipe "while sleep 1; do echo \"\$(date +P_%s.%N)\"; done"

# Super fast pipe producer, and reading fast, but droppping thing.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 2" --sub "exec sleep 20" --async_delay_msec=5 --pipe "while true; do echo \"\$(date +P_%s.%N)\"; done"

# We don't need this echo thing.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 2" --sub "exec sleep 20" --async_delay_msec=5 --pipe "while true; do date +P_%s.%N; sleep 1; done"

# Pipe that starts producing immedietly, produces for a bit, then stops.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 2" --sub "exec sleep 20" --pipe "for i in \$(seq 5); do echo \"\$(date +P_%s.%N)\"; sleep 1; done; echo BOOM; sleep 1; exit 1"

# Test dying pipe.
"${MM}" --interval_msec=100 --duration_sec=10 --pipe "echo A1; sleep 1; echo A2; sleep 1; echo A3; sleep 1; echo A4; sleep 1; echo BOOM; exit 1"

# Test invalid pipe.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 20" --pipe "while aklsjdlkj"

# Test command with comma.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "exec sleep 3; echo a,basdas,casdas"

# Test pure-shell work in sub. One doing a lot of CPU, and pipe writes, one just spinning, and one forking a lot.
"${MM}" --interval_msec=100 --duration_sec=10 --sub "while :; do echo asd; done > /dev/null" --sub "while :; do :; done" --sub "while :; do /bin/true; done >/dev/null"

# Monitor gpu and sub-process.
"${MM}" --interval_msec=100 --duration_sec=2 --sub "exec sleep 10" --gpu=min


# Sub-process monitor, then kill mm, before end of duration or sub-process finishes.
"${MM}" --interval_msec=100 --duration_sec=20 --sub "exec sleep 10" &
MMPID=$!
sleep 2
kill $MMPID

# Monitor by pid, then kill mm before end of duration.
"${MM}" --interval_msec=100 --duration_sec=20 --pid $PIDE &
MMPID=$!
sleep 2
kill $MMPID
echo "Waiting for $MMPID"
wait $MMPID || true

# TODO(baryluk): Detect sub-processes in --sub, --exec and --pipe terminating.
# For example if --pipe has incorrect format, we should not even start logging.
# If the first sample works, and fails later, we shall instead continue,
# display nan or something, emit stuff to stderr, or restart or termina also.
# (Depending on options).

# Cleanup.
kill $PIDA
echo "Waiting for $PIDA"
wait $PIDA || true
kill $PIDB
echo "Waiting for $PIDB"
wait $PIDB || true
kill $PIDC
echo "Waiting for $PIDC"
wait $PIDC || true
kill $PIDD
echo "Waiting for $PIDD"
wait $PIDD || true
kill $PIDE || true
echo "Waiting for $PIDE"
wait $PIDE || true



# Monitor by pid, kill monitored process before end of duration, then kill mm before id finishes.
sleep 3600 &
PIDA=$!
"${MM}" --interval_msec=500 --duration_sec=10 --pid $PIDA &
MMPID=$!
echo Sleeping
sleep 1
echo Sleeping
sleep 1
echo Sleeping
sleep 1
kill $PIDA
sleep 1
kill -9 $PIDA || true
echo "Waiting for $PIDA"
wait $PIDA || true
echo Sleeping
sleep 1
echo Sleeping
sleep 1
#kill $MMPID
echo "Waiting for $MMPID"
wait $MMPID || true



# --DRT-gcopt=parallel:2
# --DRT-gcopt=parallel:0
# --DRT-scanDataSeg=precise
# --DRT-scanDataSeg=conservative
# "--DRT-gcopt=gc:precise cleanup:none"
# "--DRT-gcopt=gc:precise profile:1"



# TODO:  --sub_pipe  : Start sub-process, monitor it, but also receive its output and display as a column next to it.
# This could be really handy to transport back some extra metrics from the app.
# The app doesn't nacissarly need to even do it, but instead spawn a subprocess that does something
# to monitor something, and just put it on stdout. Becuase child will write to pipe too. I think.


# $ ./multimonitor_ldc --pid -5
# std.conv.ConvException@/usr/lib/ldc/x86_64-linux-gnu/include/d/std/conv.d(2382): Unexpected '-' when converting from type string to type uint
# $ ./multimonitor_ldc --pid 0
# core.exception.AssertError@proc.d(361): Can't open stat file for pid 0
