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


function check_for_sell {
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  # Check all balances
  for f_EXCHANGE_GET_BALANCES_CMD_OUT in $(cat EXCHANGE_GET_BALANCES_CMD_OUT | egrep -v "^${CURRENCY},")
  do
    f_ASSET=$(echo ${f_EXCHANGE_GET_BALANCES_CMD_OUT} | cut -d, -f1)
    f_QUANTITY=$(echo ${f_EXCHANGE_GET_BALANCES_CMD_OUT} | cut -d, -f2)
    f_QUANTITY_CURRENCY=$(echo ${f_EXCHANGE_GET_BALANCES_CMD_OUT} | cut -d, -f3)
    f_LAST_EXCHANGE_RATE=$(echo ${f_EXCHANGE_GET_BALANCES_CMD_OUT} | cut -d, -f4)
    f_ASSET_HIST_FILE="asset-histories/${f_ASSET}${CURRENCY}.history.csv"

    # State for currency
    g_echo "SELL ${f_ASSET}: Balance: $f_QUANTITY ($f_QUANTITY_CURRENCY $CURRENCY)"
    
    # check for emergency stop
    local f_COMPLETE_BALANCE=$(tail -n1 "asset-histories/BALANCECOMPLETE${CURRENCY}.history.csv" | cut -d, -f2)
    if [[ $(echo "${f_COMPLETE_BALANCE} < ${EMERGENCY_STOP}" | bc -l) -ne 0 ]] 
    then
      local f_msg="ATTENTION! EMERGENCY STOP DUE TO POOR PERFORMANCE: BALANCE (${f_COMPLETE_BALANCE}) LOWER THEN EMERGENCY_STOP-VALUE (${EMERGENCY_STOP})"
      g_echo_error "${f_msg}"
      position_close ${f_ASSET}/${CURRENCY}
      continue
    fi
    if tail -n1 $f_ASSET_HIST_FILE | egrep -q "^$(date +%Y-%m-%d)|$(date +%Y-%m-%d -d yesterday)"
    then
      check_sell_conditions "${f_ASSET_HIST_FILE}" "${f_strategy}"
    else
      local f_msg="SELL $f_ASSET_HIST_FILE no current data of invested asset"
      g_echo_warn "${f_msg}"
      position_close ${f_ASSET}/${CURRENCY}
    fi
  done
}
