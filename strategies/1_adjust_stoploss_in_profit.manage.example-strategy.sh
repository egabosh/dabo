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


# adjust stoploss from percentage profit
from_profit=0.25
if [[ -n "$LEVERAGE" ]]
then
  g_calc "${from_profit}*${LEVERAGE}"
  from_profit=$g_calc_result
fi

# go through trading symbols
for asset in ${ASSETS[@]}
do

  # continue if no open position
  [[ -z "${p[${asset}_pnl]}" ]] && continue

  g_echo_note "Checking open positions for $asset for profit >$from_profit%"

  # calc percentual pnl with full numbers respecting leverage (real price development in percentage)
  pnl_percentage="${p[${asset}_pnl_percentage]%%.*}"
  if [[ -n "$LEVERAGE" ]]
  then
    g_calc "$pnl_percentage/$LEVERAGE"
    pnl_percentage=${g_calc_result%%.*}
  fi

  # save profit by switching stoploss in profit
  # what side are we on (long or short)
  side=${p[${asset}_side]}

  g_echo_note "Checking open $side position for $asset with PNL ${p[${asset}_pnl_percentage]}% and SL threshold if $from_profit"

  if g_num_is_higher ${p[${asset}_pnl_percentage]} $from_profit
  then

    g_echo_note "SL should be set for $asset with PNL ${p[${asset}_pnl_percentage]}% (${p[${asset}_pnl_percentage]%%.*})"
    # calculate stoploss price
    if g_num_is_higher ${p[${asset}_pnl_percentage]} 3
    then
      echo "profit larger then 3%" 1>&2
      # calculate stoploss price at 90% of profit
      g_calc "${p[${asset}_entry_price]} + 0.9 * (${p[${asset}_current_price]} - ${p[${asset}_entry_price]})"
    else
      # calculate stoploss price at 20% of profit
      g_calc "${p[${asset}_entry_price]} + 0.2 * (${p[${asset}_current_price]} - ${p[${asset}_entry_price]})"
    fi
    stoploss_price=$g_calc_result
    echo "SL should be >= $stoploss_price" 1>&2
 
    g_echo_note "check for already existing stoploss"
    for orderid in ${o[${asset}_ids]}
    do
      echo "XXXXXXXXX $orderid"
      [[ ${o[${asset}_${orderid}_stopprice]} = "null" ]] && continue
      # do nothing if current stoploss price is already larger/equal
      if [[ $side = long ]]
      then
        g_num_is_higher ${o[${asset}_${orderid}_stopprice]} ${v[${asset}_price]} && continue
        g_num_is_approx $stoploss_price ${o[${asset}_${orderid}_stopprice]} 0.01 100 && continue 2
      fi
      if [[ $side = short ]]
      then
        g_num_is_lower ${o[${asset}_${orderid}_stopprice]} ${v[${asset}_price]} && continue
        g_num_is_approx $stoploss_price ${o[${asset}_${orderid}_stopprice]} 100 0.01 && continue 2
      fi
      oldid=$orderid
    done      

    # create new stoploss
    g_echo_ok "==== New StopLoss in profit for $asset at $stoploss_price"
    order "$asset" "asset_amount:${p[${asset}_asset_amount]}" ${side} stoploss "$stoploss_price"  || continue

    # cancel old stoploss order
    [[ -n "$oldid" ]] && order_cancel_id "$asset" "$oldid"

    # cancel old limit orders
    for order_id in ${o[${asset}_ids]}
    do
      [[ ${o[${asset}_${order_id}_type]} = limit ]] || continue
      echo order_cancel_id "$asset" "$order_id"
    done

  fi

done
