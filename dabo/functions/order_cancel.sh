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


function order_cancel {
  # Info for log
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_symbol=$1
  local f_order
 
  get_symbols_ticker
  get_orders "$f_symbol"
  get_orders_array

  local f_asset=${f_symbol//:$CURRENCY/}
  f_asset=${f_asset//\//}

  if [ -n "${o[${f_asset}_present]}" ]
  then
    f_ccxt "print(${STOCK_EXCHANGE}.cancelAllOrders('$f_symbol'))"
    get_orders "$f_symbol"
    get_orders_array
  else
    g_echo_note "No orders for $f_symbol/$f_asset found"
    return 0
  fi
}


function order_cancel_all {
  # Info for log
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_order

  get_symbols_ticker
  get_orders_array

  for f_order in "${f_get_orders_array[@]}"
  do
    get_order_line_vars "$f_order"
    if [[ $f_symbol = $f_order_symbol ]]
    then
      f_ccxt "print(${STOCK_EXCHANGE}.cancelAllOrders('$f_symbol'))"
      get_orders "$f_symbol"
      get_orders_array
    fi
  done
}

function order_cancel_id {
  # Info for log
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_symbol=$1
  local f_id=$2
  local f_order

  get_symbols_ticker
  get_orders "$f_symbol"
  get_orders_array

  local f_asset=${f_symbol//:$CURRENCY/}
  f_asset=${f_asset//\//}

  if grep -q "$f_asset.*$f_id" values-orders
  then
    f_ccxt "print(${STOCK_EXCHANGE}.cancelOrder(id='${f_id}', symbol='${f_symbol}'))"
    get_orders "$f_symbol"
    get_orders_array
  else
    g_echo_note "No orders for $f_symbol/$f_asset with id $f_id found"
    return 1
  fi
}



