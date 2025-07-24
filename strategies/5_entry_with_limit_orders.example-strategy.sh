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

# Example strategy for managing open positions

##### WARNING! This strategy is only intended as an example and should not be used with real trades!!! Please develop your own strategy ######

# use 2.5% of complete balance for trades
trade_balance_percentage=2.5

# max 30% of complete balance per position
max_trade_balance_percentage=30


# calc absolute balances
g_calc "$COMPLETE_BALANCE/100*$trade_balance_percentage"
trade_balance=$g_calc_result
g_calc "$COMPLETE_BALANCE/100*$max_trade_balance_percentage"
max_trade_balance=$g_calc_result


for asset in ${ASSETS[@]}
do

  # check for already existing position
  if [[ -n "${p[${asset}_currency_amount]}" ]]
  then

    # check for max currency amount
    if g_num_is_higher ${p[${asset}_currency_amount]} $max_trade_balance
    then
      g_echo_note "Position with ${asset} already open and >$max_trade_balance (${p[${asset}_currency_amount]}) doing nothing"
      order_cancel "$asset"
      continue
    fi
  
    # check for position with stoploss in profit
    g_echo_note "check for already existing stoploss"
    for orderid in ${o[${asset}_ids]}
    do
      [[ ${o[${asset}_${orderid}_stopprice]} = "null" ]] && continue
      if g_num_is_higher ${o[${asset}_${orderid}_stopprice]} ${p[${asset}_entry_price]} && g_num_is_lower ${o[${asset}_${orderid}_stopprice]} ${v[${asset}_price]}
      then
        g_echo_note "Position with ${asset} already open with stoploss in profit (${p[${asset}_pnl_percentage]}%) - doing nothing"
        order_cancel "$asset"
        continue 2
      fi
    done
  
  fi

  s_score=${score[${asset}]}
  unset side

  if [[ $s_score -gt 7 ]]
  then
    ## Long Setup
    side=long
    entries=${entries[${asset}_long]}
    g_echo "LONG $asset | Entry: $entry | Score: $s_score"
    # cleanup old short orders
    [[ "${o[SOLUSDT_present]}" == *short* ]] && order_cancel "$asset"
  elif [[ $s_score -lt -7 ]] && [[ -n "$LEVERAGE" ]]
  then
    ## Short Setup
    side=short
    entries=${entries[${asset}_short]}
    g_echo "SHORT $asset | Entry: $entry | Score: $s_score"
    # cleanup old long orders
    [[ "${o[SOLUSDT_present]}" == *long* ]] && order_cancel "$asset"
  else
    g_echo "NO TRADE $asset | Score: $s_score"
    order_cancel "$asset"
    continue
  fi

  if [[ -n "${p[${asset}_side]}" ]]
  then
    if ! [[ ${p[${asset}_side]} = $side ]]
    then
      g_echo_note "new side $side and side of open position ${p[${asset}_side]} - Doing nothing"
      continue
    fi
  fi  

  # remove existing orders if no entries found
  [ -z "$entries" ] && order_cancel "$asset"

  # Do order
  for entry in $entries
  do
    # do order
    order "$asset" "$trade_balance" "$side" "$entry"
  done

done
