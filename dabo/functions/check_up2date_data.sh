#!/bin/bash

# Copyright (c) 2022-2025 olli
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
  if ! [[ -s "$f_histfile" ]] || [[ -z "$f_timeframe" ]]
  then
    g_echo_warn "File $f_histfile empty or not existing or timeframe ($f_timeframe) not given"
    return 1
  fi
  
  ## check for up2date data
  local f_latest_date=$(tail -n1 "$f_histfile" | cut -d, -f1)
  local f_now=$(date +%s)
  local f_latest_ts=$(date -d "$f_latest_date" +%s)
  local f_tf_seconds

  case "$f_timeframe" in
    5m)  f_tf_seconds=450 ;;
    15m) f_tf_seconds=1200 ;;
    1h)  f_tf_seconds=3600 ;;
    4h)  f_tf_seconds=14400 ;;
    1d)  f_tf_seconds=86400 ;;
    1w)  f_tf_seconds=604800 ;;
  esac
 
  if [ -n "f_tf_seconds" ]
  then
    if ! (( (f_now - f_latest_ts) <= 2 * f_tf_seconds ))
    then
      g_echo_warn "Market-Data in $f_histfile not up to date"
      return 2
    fi
  fi
  
  return 0
}
