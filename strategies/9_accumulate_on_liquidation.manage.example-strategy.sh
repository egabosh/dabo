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


[[ -z "$LEVERAGE" ]] && return 0

# go through trading symbols
for asset in ${ASSETS[@]}
do

  # if no open position continue or existin stoploss
  if [[ -z "${p[${asset}_liquidation_price]}" ]] || [[ -n "${p[${asset}_stoploss_price]}" ]]
  then
    order_cancel_idfile "$asset" "order_locked_${asset}-accumulate_on_liquidation" force
    rm -f "orders_locked_${asset}-accumulate_on_liquidation"
    continue
  fi

  g_echo_note "Checking open positions for $asset with liquidation price at ${p[${asset}_liquidation_price]}"

  # calc order price
  [[ ${p[${asset}_side]} = long ]] && g_calc "${p[${asset}_liquidation_price]}/100*100.7"
  [[ ${p[${asset}_side]} = short ]] && g_calc "${p[${asset}_liquidation_price]}/100*99.3"
  order_at=$g_calc_result

  # calc order amount
  g_calc "${p[${asset}_asset_amount]}/$LEVERAGE"
  order_amount=$g_calc_result

  order "$asset" "asset_amount:${order_amount}" "${p[${asset}_side]}" "$order_at"
  if [[ -n "${f_order_result[id]}" ]] 
  then
    echo "${f_order_result[id]}" >>"orders_locked_${asset}"
    order_cancel_idfile "$asset" "order_locked_${asset}-accumulate_on_liquidation" force
    echo "${f_order_result[id]}" >"order_locked_${asset}-accumulate_on_liquidation"
  fi

done

return 0
