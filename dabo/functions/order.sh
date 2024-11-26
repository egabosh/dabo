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


function order {
  # Info for log
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
 
  # needed vars
  local f_symbol=$1
  local f_amount=$2  # amount in $CURRENCY / if crypto_amount:XXX then amount in crypto
  local f_side=$3                   # buy/sell long/short
  local f_price=$4                  # price for limit order - if not given do market order
  local f_stoploss=$5
  local f_takeprofit=$6
  local f_params="params={"
  local f_type


  ### validity checks ###
 
  # check symbol XXX/$CURRENCY[:$CURRENCY]
  [[ $f_symbol =~ /$CURRENCY ]] || return 1

  # check side
  [ "$f_side" = "long" ] && f_side="buy"
  [ "$f_side" = "short" ] && f_side="sell"
  [[ $f_side =~ ^buy$|^sell$ ]] || return 1

  # check order type limit/market
  if [ -z "$f_price" ]
  then
    f_type="market"
    f_price=0
  else
    f_type="limit"
  fi
  
  ### validity checks end###


  # check for swap/margin trades
  if [ -n "$LEVERAGE" ]
  then
    # do some margin things

    # check for CCXT swap symbol :$CURRENCY
    [[ $f_symbol =~ : ]] || f_symbol="$f_symbol:$CURRENCY"

    # set position mode
    f_ccxt "$STOCK_EXCHANGE.setPositionMode(hedged=False, symbol='$f_symbol')" || return 1

    # set leverage
    f_ccxt "$STOCK_EXCHANGE.setLeverage($LEVERAGE, '$f_symbol')" || return 1

    # define margibn mode isolated/cross
    f_params="${f_params}'marginMode': '$MARGIN_MODE', "

    # calculate amount with leverage
    g_calc "${f_amount}*${LEVERAGE}"
    f_amount=$g_calc_result
  else
    # short/sell not possible in spot market
    [[ $f_side =~ ^sell$ ]] || return 1
  fi


  # get amount in crypto asset
  if [[ $f_amount =~ ^crypto_amount: ]]
  then
    # if given in crypto
    f_amount=${f_amount//crypto_amount:}
  else
    # on market order use current price
    if [[ $f_type = market ]]
    then
      # if given in $CURRENCY
      local f_asset=${f_symbol///*}
      currency_converter $f_amount $CURRENCY $f_asset || return 1
      f_amount=$f_currency_converter_result
    # on limit order use limit price
    elif [[ $f_type = limit ]]
    then
      g_calc "1/${f_price}*${f_amount}"
      f_amount=$g_calc_result
    fi
  fi  


  # Add stoploos and take profit if available
  if [ -n "$f_stoploss" ]
  then
    # check for long
    if [[ $f_side = buy ]] && g_num_is_higher_equal $f_stoploss $f_price
    then
      g_echo_warn "Long Order not possible: Stoploss ($f_stoploss) higher then buy price ($f_price)"
      return 1
    fi
    # check for short
    if [[ $f_side = sell ]] && g_num_is_lower_equal $f_stoploss $f_price 
    then
      g_echo_warn "Short Order not possible: Stoploss ($f_stoploss) lower then buy price ($f_price)"
      return 1
    fi 
    f_ccxt "print($STOCK_EXCHANGE.priceToPrecision('${f_symbol}', ${f_stoploss}))"
    f_stoploss=$f_ccxt_result
    f_params="${f_params}'stopLossPrice': '$f_stoploss', "
  fi
  if [ -n "$f_takeprofit" ] 
  then
    # check for long
    if [[ $f_side = buy ]] && g_num_is_lower_equal $f_takeprofit $f_price
    then
      g_echo_warn "Long Order not possible:TakeProfit ($f_takeprofit) lower then buy price ($f_price)"
      return 1
    fi 
    # check for short
    if [[ $f_side = sell ]] && g_num_is_higher_equal $f_takeprofit $f_price
    then
      g_echo_warn "Short Order not possible:TakeProfit ($f_takeprofit) higher then buy price ($f_price)"
      return 1
    fi 
    f_ccxt "print($STOCK_EXCHANGE.priceToPrecision('${f_symbol}', ${f_takeprofit}))"
    f_takeprofit=$f_ccxt_result
    f_params="${f_params}'takeProfitPrice': '$f_takeprofit', "
  fi
 
  # end up params syntax with "}"
  f_params="${f_params}}"  

  # calculate price amount precision
  f_ccxt "print($STOCK_EXCHANGE.amountToPrecision('${f_symbol}', ${f_amount}))"
  f_amount=$f_ccxt_result
  f_ccxt "print($STOCK_EXCHANGE.priceToPrecision('${f_symbol}', ${f_price}))"
  f_price=$f_ccxt_result

  # do the order
  local f_order="symbol='${f_symbol}', type='$f_type', price=$f_price, amount=${f_amount}, side='${f_side}', ${f_params}"
  echo "$f_order" | notify.sh -s "ORDER"
  f_ccxt "print($STOCK_EXCHANGE.createOrder(${f_order}))" || return 1

  # refresh orders and positions
  get_orders "$f_symbol"
  get_positions
  get_position_array
  get_orders_array
}

