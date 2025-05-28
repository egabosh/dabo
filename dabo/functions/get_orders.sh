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


function get_orders {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
  
  local f_symbol=$1
  local f_symbol_file

  # get orders of all symbols available if symbol argument is not given
  local f_symbols=()
  if [[ -z "$f_symbol" ]] 
  then
    for f_symbol in "${f_symbols_array_trade[@]}"
    do
      if [[ -z "$LEVERAGE" ]] 
      then
        [[ $f_symbol =~ /${CURRENCY}$ ]] && f_symbols+=("$f_symbol")
      else
        [[ $f_symbol =~ /${CURRENCY}:${CURRENCY}$ ]] && f_symbols+=("$f_symbol")
      fi
    done
  else
   f_symbols+=("$f_symbol")
  fi
  [[ -z "$f_symbols" ]]  && return 1

  for f_symbol in ${f_symbols_array_trade[@]}
  do
    f_symbol_file=${f_symbol//:*}
    f_symbol_file=${f_symbol_file///}
    g_echo_note "Getting orders from $f_symbol to \"CCXT_ORDERS_$f_symbol_file\""
    if f_ccxt "print($STOCK_EXCHANGE.fetchOpenOrders(symbol='${f_symbol}'))"
    then
      echo $f_ccxt_result | tee "CCXT_ORDERS_${f_symbol_file}_RAW" | jq -r "
.[] |
select(.status==\"open\") |
.symbol  + \",\" + .type + \",\" + .side + \",\" + (.price|tostring) + \",\" + (.amount|tostring) + \",\" + .id  + \",\" + (.stopLossPrice|tostring) + \",\" + (.takeProfitPrice|tostring) + \",\" + (.stopPrice|tostring)
" >"CCXT_ORDERS_${f_symbol_file}"
    else
      rm -f "CCXT_ORDERS_${f_symbol_file}_RAW" "CCXT_ORDERS_${f_symbol_file}"
      continue
    fi
  done
  cat CCXT_ORDERS_*${CURRENCY} >CCXT_ORDERS 2>/dev/null
  
  get_orders_array
}

function get_orders_array {
  local f_order
  
  # clear/create assoziative array o
  unset o
  declare -Ag o

  # build array from lines in CCXT_ORDERS
  g_array CCXT_ORDERS f_get_ordes_array
  for f_order in ${f_get_ordes_array[@]}
  do
    get_order_line_vars "$f_order"
  done

  # write values to file
  for i in "${!o[@]}"
  do
    echo "\${o[$i]}=${o[$i]}"
  done | sort >values-orders.new
  mv values-orders.new values-orders

}

function get_order_line_vars {
  local f_order_line=$1

  g_array $f_order_line f_order_array ,

  f_order_symbol=${f_order_array[0]}
  local f_asset=${f_order_symbol//:$CURRENCY/}
  f_asset=${f_asset//\//}

  local f_order_type=${f_order_array[1]}
  local f_order_side=${f_order_array[2]}
  local f_type
  if [[ $f_order_type = limit ]] 
  then 
    [[ $f_order_side = buy ]] && f_type="open_long"
    [[ $f_order_side = sell ]] && f_type="open_short"
  fi
  if [[ $f_order_type = Stop ]]
  then
    [[ $f_order_side = buy ]] && f_type="sl_close_short"
    [[ $f_order_side = sell ]] && f_type="sl_close_long"
  fi
  if [[ $f_order_type == @(MarketIfTouched|LimitIfTouched) ]]
  then
    [[ $f_order_side = buy ]] && f_type="tp_close_short"
    [[ $f_order_side = sell ]] && f_type="tp_close_long"
  fi
 
  if [[ -z "${o[${f_asset}_present]}" ]]  
  then
    o[${f_asset}_present]=${f_type}
  else
    o[${f_asset}_present]="${o[${f_asset}_present]} ${f_type}"
  fi
  o[${f_asset}_${f_type}_type]=${f_order_array[1]}
  o[${f_asset}_${f_type}_side]=${f_order_array[2]}
  o[${f_asset}_${f_type}_entry_price]=${f_order_array[3]}
  o[${f_asset}_${f_type}_amount]=${f_order_array[4]}
  o[${f_asset}_${f_type}_id]=${f_order_array[5]}
  o[${f_asset}_${f_type}_stoplossprice]=${f_order_array[6]}
  o[${f_asset}_${f_type}_takeprofitprice]=${f_order_array[7]}
  o[${f_asset}_${f_type}_stopprice]=${f_order_array[8]}
}


