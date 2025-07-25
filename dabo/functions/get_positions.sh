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


function get_positions {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_symbol f_symbols f_asset f_stoploss f_takeprofit f_line

  get_symbols_ticker

  # build python array of symbols
  for f_symbol in "${f_symbols_array_trade[@]}"
  do
    if [[ -z "$LEVERAGE" ]] 
    then
      [[ $f_symbol =~ /${CURRENCY}$ ]] && f_symbols+="'$f_symbol', "
    else
      [[ $f_symbol =~ /${CURRENCY}:${CURRENCY}$ ]] && f_symbols+="'$f_symbol', "
    fi
  done

  [[ -z "$f_symbols" ]]  && return 1
  f_ccxt "print($STOCK_EXCHANGE.fetchPositions(symbols=[${f_symbols}]))" && echo $f_ccxt_result >CCXT_POSITIONS_RAW
  jq -r "
.[] |
select(.entryPrice != 0) |
.symbol + \",\" + (.collateral|tostring) + \",\" + (.entryPrice|tostring) + \",\" + .side  + \",\" + (.leverage|tostring) + \",\" + (.liquidationPrice|tostring) + \",\" + (.stopLossPrice|tostring) + \",\" + (.takeProfitPrice|tostring) + \",\" + (.contracts|tostring)
" CCXT_POSITIONS_RAW >CCXT_POSITIONS

  # check for takeprofit/stoploss orders if not in CCXT output (needed for phememx and maybe more exchanges)
  get_position_array
  for f_symbol in ${f_symbols_array_trade[@]}
  do
    f_asset=${f_symbol//:$CURRENCY/}
    f_asset=${f_asset//\//}
    # only continue if position for symbol exists and stoploss or takeprofit is empty
    [[ -z "${p[${f_asset}_entry_price]}" ]]  && continue

    if [[ -n "${p[${f_asset}_stoploss_price]}" && -n "${p[${f_asset}_takeprofit_price]}" ]]
    then
      continue
    fi

    [[ -n "${p[${f_asset}_stoploss_price]}" ]] && continue
    [[ -n "${p[${f_asset}_takeprofit_price]}" ]]  && continue
  
    # check for position side
    [[ "${p[${f_asset}_side]}" = "long" ]]  && f_action=sell
    [[ "${p[${f_asset}_side]}" = "short" ]]  && f_action=buy
    if [[ ${p[${f_asset}_side]} =~ long|short ]]
    then
      # search for stoploss/takeprofit in CCXT_ORDERS and edit CCXT_POSITIONS
      while IFS= read -r f_line
      do
        # stoploss
        if [[ $f_line == "$f_symbol,Stop,$f_action,"* ]]
        then
          IFS=',' read -ra f_fields <<< "$f_line"
          f_stoploss="${f_fields[8]}"
          awk -F, -v symbol="$f_symbol" -v side="${p[${f_asset}_side]}" -v newval="$f_stoploss" 'BEGIN{OFS=","} $1==symbol && $4==side{$7=newval} 1' CCXT_POSITIONS >CCXT_POSITIONS.new
          mv CCXT_POSITIONS.new CCXT_POSITIONS
        fi
        # takeprofit
        if [[ $f_line =~ ^$f_symbol,(MarketIfTouched|LimitIfTouched),$f_action, ]]
        then
          IFS=',' read -ra f_fields <<< "$f_line"
          f_takeprofit="${f_fields[8]}"
          awk -F, -v symbol="$f_symbol" -v side="${p[${f_asset}_side]}" -v newval="$f_takeprofit" 'BEGIN{OFS=","} $1==symbol && $4==side{$8=newval} 1' CCXT_POSITIONS >CCXT_POSITIONS.new
          mv CCXT_POSITIONS.new CCXT_POSITIONS
        fi
      done < CCXT_ORDERS
    fi
  done
 
  return 0
}

function get_position_array {
  local f_position

  # clear/create assoziative array p
  unset p
  declare -Ag p
  get_symbols_ticker
  # build array from lines in CCXT_POSITIONS
  g_array CCXT_POSITIONS f_get_positions_array
  for f_position in ${f_get_positions_array[@]}
  do
    get_position_line_vars "$f_position"
  done

  # write values to file
  for i in "${!p[@]}"
  do
    echo "\${p[$i]}=${p[$i]}"
  done | sort >values-positions.new
  mv values-positions.new values-positions

}

function get_position_line_vars {
  local f_pos_line=$1
  g_array $f_pos_line f_position_array ,

  f_position_symbol=${f_position_array[0]}
  local f_asset=${f_position_symbol//:$CURRENCY/}
  f_asset=${f_asset//\//}

  printf -v f_position_currency_amount %.2f ${f_position_array[1]}
  p[${f_asset}_currency_amount]=$f_position_currency_amount

  f_position_entry_price=${f_position_array[2]}
  p[${f_asset}_entry_price]=$f_position_entry_price

  # mark price seems not lates price in very case so take the ticker
  p[${f_asset}_current_price]=${v[${f_asset}_price]}
  f_position_current_price=${v[${f_asset}_price]}

  f_position_side=${f_position_array[3]}
  [[ -z "$f_position_side" ]]  && f_position_side="long"
  p[${f_asset}_side]=$f_position_side

  f_position_leverage=${f_position_array[4]}
  [[ $f_position_leverage = null ]] && f_position_leverage="1"
  p[${f_asset}_leverage]=$f_position_leverage
   
  p[${f_asset}_liquidation_price]=${f_position_array[5]}
  f_position_liquidation_price=${f_position_array[5]}

  if ! [[ ${f_position_array[6]} = null ]]
  then
    p[${f_asset}_stoploss_price]=${f_position_array[6]}
    f_position_stoploss_price=${f_position_array[6]}
  fi

  if ! [[ ${f_position_array[7]} = null ]]
  then
    p[${f_asset}_takeprofit_price]=${f_position_array[7]}
    f_position_takeprofit_price=${f_position_array[7]}
  fi

  #printf -v f_position_asset_amount %.2f ${f_position_array[8]}
  #p[${f_asset}_asset_amount]=$f_position_asset_amount
  p[${f_asset}_asset_amount]=${f_position_array[8]}

  # calc pnl percentage
  if [[ $f_position_side = long ]]
  then
    g_percentage-diff $f_position_entry_price $f_position_current_price
  else
    g_percentage-diff $f_position_current_price $f_position_entry_price
  fi
  g_calc "$g_percentage_diff_result*$f_position_leverage"
  f_position_pnl_percentage=$g_calc_result
  p[${f_asset}_pnl_percentage]=$g_calc_result

  # calc pnl
  g_calc "$f_position_currency_amount/100*$f_position_pnl_percentage"
  printf -v f_position_pnl %.2f $g_calc_result
  p[${f_asset}_pnl]=$f_position_pnl

}


