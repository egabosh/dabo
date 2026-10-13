#!/bin/bash

. /etc/bash/gaboshlib.include

while true
do

  PID=1

  # wait interval time
  INTERVALTIME=$1
  [[ -z "$INTERVALTIME" ]] && INTERVALTIME=2m
  [[ $INTERVALTIME = "1w" ]] && INTERVALTIME=7d
  g_echo_debug "WATCHDOG: sleep time $INTERVALTIME"
  g_healthcheck_rotate
  sleep $INTERVALTIME

  [[ -d /proc/$PID ]] || continue

  # Liveness gate: only act when the waiting marker is MISSING.
  [[ -f /tmp/$PID-waiting ]] && continue

  # Repair 2026-10-01: drop the CPU-time heuristic.
  # PID 1 is the entrypoint bash ("bash -lc '... | tee ...'") and has almost
  # no CPU time of its own while the full loop runs - the work happens in
  # child processes. The old check therefore compared a flat PID-1 CPU time
  # and killed a perfectly healthy bot. The waiting marker is the single
  # reliable indicator, so the decision now depends on it alone.
  CMDLINE=$(cat /proc/$PID/cmdline | tr '\0' ' ')
  g_echo_error "WATCHDOG: process ($CMDLINE) inactive (marker /tmp/$PID-waiting missing)"
  kill -15 $PID

done
