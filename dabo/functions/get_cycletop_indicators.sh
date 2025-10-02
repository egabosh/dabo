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

# Assumption: crypto/bitcoin follows the money supply M2 with a 3-month delay
function get_cycletop_indicators {
  
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_histfile="asset-histories/MARKETDATA_BTC_CYCLE_TOP_INDICATORS.history.1d.csv"

  g_wget -q https://colintalkscrypto.com/cbbi/data/latest.json -O - >${f_histfile}.raw
  jq -r '
   (.Price | keys_unsorted[] | tonumber) as $timestamp
   | ($timestamp | strftime("%Y-%m-%d")) as $date
   | "\($date),\(.Price[$timestamp 
   | tostring] // ""),\(.PiCycle[$timestamp 
   | tostring] // ""),\(.RUPL[$timestamp 
   | tostring] // ""),\(.RHODL[$timestamp 
   | tostring] // ""),\(.Puell[$timestamp 
   | tostring] // ""),\(.["2YMA"][$timestamp 
   | tostring] // ""),\(.Trolololo[$timestamp 
   | tostring] // ""),\(.MVRV[$timestamp 
   | tostring] // ""),\(.ReserveRisk[$timestamp 
   | tostring] // ""),\(.Woobull[$timestamp 
   | tostring] // ""),\(.Confidence[$timestamp 
   | tostring] // "")"
  ' ${f_histfile}.raw >${f_histfile}.new || return 1
   
   touch "${f_histfile}"
   egrep -h ^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9], "${f_histfile}.new" "${f_histfile}" | sort -k1,1 -t, -u >"${f_histfile}.tmp"
   mv "${f_histfile}.tmp" "${f_histfile}"
}

