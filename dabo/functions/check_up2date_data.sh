#!/bin/bash

# Copyright (c) 2022-2026 olli
#
# This file is part of dabo (crypto bot).
# 
# dabo is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# dabo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with dabo. If not, see <http://www.gnu.org/licenses/>.

function check_up2date_data {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_histfile=$1
  local f_timeframe=$2

  if [[ -z "$f_timeframe" ]]
  then
    case "$f_histfile"
    in
      *.5m.csv) f_timeframe=5m ;;
      *.15m.csv) f_timeframe=15m ;;
      *.1h.csv) f_timeframe=1h ;;
      *.4h.csv) f_timeframe=4h ;;
      *.1d.csv) f_timeframe=1d ;;
      *.1w.csv) f_timeframe=1w ;;
      *.1M.csv) f_timeframe=1M ;;
    esac
  fi

  if ! [[ -s "$f_histfile" ]] || [[ -z "$f_timeframe" ]]
  then
    g_echo_warn "File $f_histfile empty or not existing or timeframe ($f_timeframe) not given"
    return 1
  fi
  
  ## check for up2date data
  local f_latest_date=$(tail -n1 "$f_histfile" | cut -d, -f1)
  # sanity guard: ignore corrupt future timestamps (e.g. 2517) that would
  # otherwise make the file look "up to date" forever
  local f_latest_year=${f_latest_date:0:4}
  if [[ "$f_latest_year" =~ ^[0-9]{4}$ ]] && (( 10#$f_latest_year > 2100 ))
  then
    f_latest_date=$(awk -F, '{ y=substr($1,1,4)+0; if (y>=1990 && y<=2100) last=$1 } END { print last }' "$f_histfile")
  fi
  # no plausible row at all (e.g. file with only corrupt rows):
  # report stale instead of running "date -d ''" into an arithmetic error
  if [[ -z "$f_latest_date" ]]
  then
    g_echo_warn "No plausible date in $f_histfile"
    return 2
  fi
  local f_now=$(date +%s)
  local f_latest_ts=$(date -d "$f_latest_date" +%s)
  local f_tf_seconds

  case "$f_timeframe"
  in
    5m)  f_tf_seconds=450 ;;
    15m) f_tf_seconds=1200 ;;
    1h)  f_tf_seconds=3600 ;;
    4h)  f_tf_seconds=14400 ;;
    1d)  f_tf_seconds=86400 ;;
    1w)  f_tf_seconds=604800 ;;
    1M)  f_tf_seconds=2678400 ;;
  esac
 
  if [ -n "f_tf_seconds" ]
  then
    if ! (( (f_now - f_latest_ts) <= 2 * f_tf_seconds ))
    then
      g_echo_warn "Data in $f_histfile not up to date (${f_latest_date})"
      return 2
    fi
  fi
 
  g_echo_ok "Data in $f_histfile up to date (${f_latest_date})"
  return 0
}
