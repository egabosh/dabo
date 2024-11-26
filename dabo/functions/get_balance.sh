#!/bin/bash

# Copyright (c) 2022-2024 olli
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

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
  
  f_ccxt "print(${STOCK_EXCHANGE}.fetch_balance ({\"currency\": \"$CURRENCY\"}))" && echo $f_ccxt_result >CCXT_BALANCE

  # get current investmentbalance
  f_CURRENCY_BALANCE=$(jq -r ".${CURRENCY}.free" CCXT_BALANCE)
  if g_num_valid_number "${f_CURRENCY_BALANCE}"
  then
    g_echo_note "=== Investmentbudget: $f_CURRENCY_BALANCE $CURRENCY"
    printf -v CURRENCY_BALANCE %.2f ${f_CURRENCY_BALANCE}
  else
    g_echo_warn "Could not determine CURRENCY_BALANCE (${f_CURRENCY_BALANCE} ${CURRENCY}) from file CCXT_BALANCE $(tail -n 10 CCXT_BALANCE)"
    unset f_ccxt_initialized
    return 3
  fi

  f_USED_BALANCE=$(jq -r ".${CURRENCY}.used" CCXT_BALANCE)
  printf -v USED_BALANCE %.2f ${f_USED_BALANCE}
  f_COMPLETE_BALANCE=$(jq -r ".${CURRENCY}.total" CCXT_BALANCE)
  printf -v COMPLETE_BALANCE %.2f ${f_COMPLETE_BALANCE}

  # write balance history
  g_echo_note "=== Total Balance: $f_COMPLETE_BALANCE $CURRENCY"
  g_echo_note "=== Free Balance: $f_CURRENCY_BALANCE $CURRENCY"
  g_echo_note "=== Used Balance: $f_USED_BALANCE $CURRENCY"
  echo "$f_timestamp,$COMPLETE_BALANCE" >>"asset-histories/BALANCECOMPLETE${CURRENCY}.history.csv"
  echo "$f_timestamp,$USED_BALANCE" >>"asset-histories/BALANCEUSED${CURRENCY}.history.csv"
  echo "$f_timestamp,$CURRENCY_BALANCE" >>"asset-histories/BALANCE${CURRENCY}.history.csv"

}

