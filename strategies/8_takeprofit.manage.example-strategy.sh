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

  g_echo_note "Checking open positions for $asset"
  if [[ -z "${p[${asset}_asset_amount]}" ]] 
  then
    rm -f "orders_locked_${asset}-takeprofit"
    continue
  fi 
  
  unset takeprofit_price

  # long positions
  [[ ${p[${asset}_side]} = "long" ]] && for exit in ${exits[${asset}_long]}
  do
    if g_num_is_higher $exit ${p[${asset}_entry_price]}
    then
      [[ -z "$takeprofit_price" ]] && takeprofit_price=$exit
      g_num_is_higher $exit $takeprofit_price && takeprofit_price=$exit
    fi
  done

  # short positions
  [[ ${p[${asset}_side]} = "short" ]] && for exit in ${exits[${asset}_short]}
  do
    if g_num_is_lower $exit ${p[${asset}_entry_price]}
    then
      [[ -z "$takeprofit_price" ]] && takeprofit_price=$exit
      g_num_is_lower $exit $takeprofit_price && takeprofit_price=$exit
    fi
  done

  # calc order amount
  g_calc "${p[${asset}_asset_amount]}/$LEVERAGE"
  order_amount=$g_calc_result

  order "$asset" "asset_amount:${p[${asset}_asset_amount]}" "${p[${asset}_side]}" takeprofit "" "$takeprofit_price" 
  if [[ -n "${f_order_result[id]}" ]] 
  then
    echo "${f_order_result[id]}" >>"orders_locked_${asset}"
    order_cancel_idfile "$asset" "order_locked_${asset}-takeprofit" force
    echo "${f_order_result[id]}" >"order_locked_${asset}-takeprofit"
  fi

done

return 0

