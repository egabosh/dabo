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


function get_balance {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  f_ccxt "print(${STOCK_EXCHANGE}.fetch_balance ({\"currency\": \"$CURRENCY\"}))" && echo $f_ccxt_result >CCXT_BALANCE_RAW

  # get current investmentbalance
  FREE_BALANCE=$(jq -r ".${CURRENCY}.free" CCXT_BALANCE_RAW)
  if g_num_valid_number "${FREE_BALANCE}"
  then
    printf -v FREE_BALANCE %.2f ${FREE_BALANCE}
  else
    g_echo_warn "Could not determine FREE_BALANCE (${FREE_BALANCE} ${CURRENCY}) from file CCXT_BALANCE_RAW $(tail -n 10 CCXT_BALANCE_RAW)"
    unset f_ccxt_initialized
    return 3
  fi

  local f_USED_BALANCE=$(jq -r ".${CURRENCY}.used" CCXT_BALANCE_RAW)
  printf -v USED_BALANCE %.2f ${f_USED_BALANCE}
  local f_COMPLETE_BALANCE=$(jq -r ".${CURRENCY}.total" CCXT_BALANCE_RAW)
  printf -v COMPLETE_BALANCE %.2f ${f_COMPLETE_BALANCE}

  # write balance history
  g_echo_note "Total Balance: $COMPLETE_BALANCE $CURRENCY"
  g_echo_note "Free Balance:  $FREE_BALANCE $CURRENCY"
  g_echo_note "Used Balance:  $USED_BALANCE $CURRENCY"
  echo "$f_timestamp,$COMPLETE_BALANCE" >>"asset-histories/BALANCECOMPLETE${CURRENCY}.history.csv"
  echo "$f_timestamp,$USED_BALANCE" >>"asset-histories/BALANCEUSED${CURRENCY}.history.csv"
  echo "$f_timestamp,$FREE_BALANCE" >>"asset-histories/BALANCE${CURRENCY}.history.csv"
  echo "$COMPLETE_BALANCE,$FREE_BALANCE,$USED_BALANCE" >CCXT_BALANCE

}

