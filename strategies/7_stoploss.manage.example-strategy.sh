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



# go through trading symbols
for asset in ${ASSETS[@]}
do

  g_echo_note "Checking open positions for $asset"
  [[ -z "${p[${asset}_asset_amount]}" ]] && continue

  unset stoploss_price

  # long positions
  [[ ${p[${asset}_side]} = "long" ]] && for exit in ${exits[${asset}_short]}
  do
    if g_num_is_lower $exit ${p[${asset}_breakeven_price]} && g_num_is_lower $exit ${v[${asset}_price]}
    then
      [[ -z "$stoploss_price" ]] && stoploss_price=$exit
      g_num_is_lower $exit $stoploss_price && stoploss_price=$exit
    fi
  done

  # short positions
  [[ ${p[${asset}_side]} = "short" ]] && for exit in ${exits[${asset}_long]}
  do
    if g_num_is_higher $exit ${p[${asset}_breakeven_price]} && g_num_is_higher $exit ${v[${asset}_price]}
    then
      [[ -z "$stoploss_price" ]] && stoploss_price=$exit
      g_num_is_higher $exit $stoploss_price && stoploss_price=$exit
    fi
  done

  # calc order amount
  g_calc "${p[${asset}_asset_amount]}/$LEVERAGE"
  order_amount=$g_calc_result

  [[ -n "$stoploss_price" ]] && order "$asset" "asset_amount:${p[${asset}_asset_amount]}" "${p[${asset}_side]}" stoploss "$stoploss_price"
  if [[ -n "${f_order_result[id]}" ]]
  then
    echo "${f_order_result[id]}" >>"orders_locked_${asset}"
    order_cancel_idfile "$asset" "order_locked_${asset}-stoploss" force
    echo "${f_order_result[id]}" >"order_locked_${asset}-stoploss"
  fi

done

return 0

