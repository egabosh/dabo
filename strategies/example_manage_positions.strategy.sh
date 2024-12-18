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

# Example strategy for managing open positions

g_echo_note "EXAMPLE Strategy for managing open positions"

##### WARNING! This strategy is only intended as an example and should not be used with real trades. Please develop your own strategy ######

# if you want to use this remove the next line with return 0
return 0

# get vars with positions
get_position_array

# go through trading symbols
for symbol in ${f_symbols_array_trade[@]}
do
  asset=${symbol//:$CURRENCY/}
  asset=${asset//\//}

  # adjust stoploss from percentage profit
  from_profit=0.5
  if [ -n "$LEVERAGE" ]
  then
    g_calc "${from_profit}*${LEVERAGE}"
    from_profit=$g_calc_result
  fi

  # save profit by switching stoploss in profit
  if [ -n "${p[${asset}_pnl]}" ]
  then

    # what side are we on (long or short)
    side=${p[${asset}_side]}
  
    g_echo_note "Checking open $side position for $f_asset"

    if g_num_is_higher ${p[${asset}_pnl_percentage]} $from_profit
    then
      # calculate stoploss price with half of current pnl
      g_calc "${p[${asset}_current_price]}-((${p[${asset}_current_price]}-${p[${asset}_entry_price]})/2)"
      stoploss_price=$g_calc_result
   
      # check for already existing stoploss
      if [ -n "${o[${asset}_sl_close_${side}_id]}" ]
      then
        
        # do nothing if current stoploss price is already larger/equal then half of current pnl
        if [[ $side = long ]]
        then
          g_num_is_higher_equal ${o[${asset}_sl_close_${side}_stopprice]} $stoploss_price && continue
        fi
        if [[ $side = short ]]
        then
          g_num_is_lower_equal ${o[${asset}_sl_close_${side}_stopprice]} $stoploss_price && continue
        fi
        
        # cancel existing stoploss order
        order_cancel_id "$symbol" "${o[${asset}_sl_close_${side}_id]}" || continue
      fi
      
      # create new stoploss
      g_echo_ok "==== New StopLoss in profit for $asset at $stoploss_price"
      order "$symbol" "asset_amount:${p[${asset}_asset_amount]}" ${side} stoploss "$stoploss_price"  

    fi
  fi

done

