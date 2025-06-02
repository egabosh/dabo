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


function check_for_buy {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@" 
 
  g_echo_ok "Investmentbudget: $CURRENCY_BALANCE $CURRENCY" 
  
  # check for emergency stop
  local f_COMPLETE_BALANCE=$(tail -n1 "asset-histories/BALANCECOMPLETE${CURRENCY}.history.csv" | cut -d, -f2)
  if [[ $(echo "${f_COMPLETE_BALANCE} < ${EMERGENCY_STOP}" | bc -l) -ne 0 ]] 
  then
    g_echo_note "BUY ATTENTION! EMERGENCY STOP DUE TO POOR PERFORMANCE: BALANCE (${f_COMPLETE_BALANCE}) LOWER THEN EMERGENCY_STOP-VALUE (${EMERGENCY_STOP})"
    return 0
  fi

  ## Generate grep regex for already invested assets
  #f_investedassets_regex=$(cat EXCHANGE_GET_BALANCES_CMD_OUT | cut -d, -f1 | perl -pe 's/^/\^/; s/\n/\|/' | perl -pe 's/\|$//')

  if ! [[ -s ASSETS ]]  
  then
    g_echo_note "BUY file ASSETS empty $(ls -l ASSETS)"
    return 0
  fi

  # go through highest assets
  local f_line
  for f_ASSET in $(cat ASSETS | egrep -v "${BLACKLIST}")
  do

    f_ASSET_HIST_FILE="asset-histories/${f_ASSET}.history.csv"

    if [[ $(tail -n 155 "$f_ASSET_HIST_FILE" | egrep -v ",,|,$" | wc -l) -ge 150 ]] 
    then
      if tail -n1 $f_ASSET_HIST_FILE | egrep -q "^$(date +%Y-%m-%d)|$(date +%Y-%m-%d -d yesterday)"
      then
        g_echo_note "BUY $f_ASSET_HIST_FILE checking conditions"
        check_buy_conditions "${f_ASSET_HIST_FILE}" "${f_strategy}"
      else
        g_echo_note "BUY $f_ASSET_HIST_FILE no current data - ignoring"
      fi
    else
      g_echo_note "BUY $f_ASSET_HIST_FILE not enough data - waiting for complete values"
    fi
  
  done
}




