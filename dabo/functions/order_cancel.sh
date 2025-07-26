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


function order_cancel {
  
  # debug
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_symbol=$1
  local f_force=$2
  local f_order
 
  # check symbol XXX/$CURRENCY[:$CURRENCY]
  if ! [[ $f_symbol =~ /$CURRENCY ]]
  then
    f_symbol=${f_symbol%$CURRENCY}
    f_symbol=${f_symbol}/${CURRENCY}
    [[ -n "$LEVERAGE" ]] && f_symbol=${f_symbol}:${CURRENCY}
  fi
  local f_asset=${f_symbol//:$CURRENCY/}
  f_asset=${f_asset//\//}

  get_orders "$f_symbol"
  get_orders_array

  for f_order in ${o[${f_asset}_ids]}
  do
    order_cancel_id "$f_symbol" "$f_order" $f_force
  done

}


function order_cancel_all {
 
  # debug
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_asset

  for f_asset in $(cut -d\[ -f2 values-orders | cut -d_ -f1 | sort -u)
  do
    g_echo_note "Cancelling all orders for $f_asset"
    order_cancel $f_asset
  done
  
}

function order_cancel_id {

  # debug
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN


  local f_symbol=$1
  local f_id=$2
  local f_force=$3
  local f_fail

  get_symbols_ticker
  get_orders "$f_symbol"
  get_orders_array

  # check symbol XXX/$CURRENCY[:$CURRENCY]
  if ! [[ $f_symbol =~ /$CURRENCY ]]
  then
    f_symbol=${f_symbol%$CURRENCY}
    f_symbol=${f_symbol}/${CURRENCY}
    [[ -n "$LEVERAGE" ]] && f_symbol=${f_symbol}:${CURRENCY}
  fi
  local f_asset=${f_symbol//:$CURRENCY/}
  f_asset=${f_asset//\//}

  # check of order exists
  if [[ -n "${o[${f_asset}_${f_id}_type]}" ]]
  then

    # check if order is locked
    if grep -q "$f_id" "orders_locked_${f_asset}" 2>/dev/null && [[ -z "$f_force" ]]
    then
      g_echo_note "Order ${f_id} of ${f_asset} locked"
      return 0
    fi

    # cancel order
    g_echo_note "Cancelling order ${f_id} of ${f_asset}"
    f_ccxt "print(${STOCK_EXCHANGE}.cancelOrder(id='${f_id}', symbol='${f_symbol}'))" || f_fail=1
    get_orders "$f_symbol"
    get_orders_array

  else
    g_echo_note "No orders for $f_symbol/$f_asset with id $f_id found"
  fi

  [[ -s "orders_locked_${asset}" ]] && sed -i "/$f_id/d" "orders_locked_${f_asset}"
  [[ -n "$f_fail" ]] && [[ -n ${o[${f_asset}_${f_id}_type]} ]] && return 1

}

function order_cancel_idfile {

  # debug
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_symbol=$1
  local f_file=$2
  local f_force=$3
  local f_order_id f_fail

  [[ -s "$f_file" ]] && while read -r f_order_id
  do
    order_cancel_id $f_symbol $f_order_id $f_force || f_fail=1
  done <"$f_file"

  # remove file if empty
  [[ -s "$f_file" ]] || rm -f "$f_file"

  [[ -n "$f_fail" ]] && return 1
  return 0

}

