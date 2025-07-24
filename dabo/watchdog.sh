#!/bin/bash

. /etc/bash/gaboshlib.include

declare -A CPUTTIMES

while true
do

  PID=1
  CPUTIMEPRE=$(ps -p "$PID" -o cputime= | tr -d ' ')
  
  CPUTTIMES[$PID]=$CPUTIME
  
  # wait interval time
  INTERVALTIME=$1
  [[ -z "$INTERVALTIME" ]] && INTERVALTIME=2m
  [[ $INTERVALTIME = "1w" ]] && INTERVALTIME=7d
  g_echo_note "WATCHDOG: sleep time $INTERVALTIME"
  sleep $INTERVALTIME

  [[ -d /proc/$PID ]] || continue
  [[ -f /tmp/$PID-waiting ]] && continue
  
  # check for changed cpu time / activity
  CPUTIMEPOST=$(ps -p "$PID" -o cputime= | tr -d ' ')
  [[ $CPUTIMEPOST = 00:00:00 ]] && continue
  if [[ $CPUTIMEPRE = $CPUTIMEPOST ]]
  then
    CMDLINE=$(cat /proc/1/cmdline | tr '\0' ' ')
    g_echo_error "WATCHDOG: process ($CMDLINE) inactive for more then $INTERVALTIME ($CPUTIMEPRE = $CPUTIMEPOST)"
    kill -15 $PID
  fi

done

