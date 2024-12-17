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
  local f_amount=$2  # amount in $CURRENCY / if asset_amount:XXX then amount in invested asset
  local f_side=$3                   # buy/sell long/short
  local f_price=$4                  # price for limit order - if "0" do market order - "stoploss" for pure StopLoss Order and "takeprofit" for pure TakeProfit Order
  local f_stoploss=$5
  local f_takeprofit=$6
  local f_params="params={"
  local f_type f_side_opposite f_pos_side f_side_opposide f_trigger_sl f_trigger_tp

  ### validity checks ###

  if [ -z "$f_symbol" ] || [ -z "$f_amount" ] || [ -z "$f_side" ] || [ -z "$f_price" ]
  then
    g_echo_error "Missing values!
Usage: order symbol amount side price [stoploss] [takeprofit]
Given: ${FUNCNAME} $@"
    return 1
  fi

  # check symbol XXX/$CURRENCY[:$CURRENCY]
  [[ $f_symbol =~ /$CURRENCY ]] || return 1

  # check side
  if [ "$f_side" = "long" ] || [ "$f_side" = "buy" ]
  then
    f_side="buy"
    f_pos_side="Long"
    f_side_opposide="sell"
    f_trigger_sl="down"
    f_trigger_tp="up"
  fi
  if [ "$f_side" = "short" ] || [ "$f_side" = "sell" ]
  then
    f_side="sell"
    f_pos_side="Short"
    f_side_opposide="buy"
    f_trigger_sl="up"
    f_trigger_tp="down"
  fi
  [[ $f_side =~ ^buy$|^sell$ ]] || return 1

  # check order type limit/market
  if [[ $f_price = 0 ]]
  then
    f_type="market"
  elif [[ $f_price = stoploss ]]
  then
    f_type="stoploss" 
    f_price="None"
  elif [[ $f_price = takeprofit ]]
  then
    f_type="takeprofit"
    f_price="None"
  else
    f_type="limit"
  fi
  
  ### validity checks end ###


  # get amount in target asset
  if [[ $f_amount =~ ^asset_amount: ]] 
  then
    # if given in target
    f_amount=${f_amount//asset_amount:}
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

    # define margin mode isolated/cross
    #[[ $f_type =~ limit|market ]] && 
    f_params="${f_params}'marginMode': '$MARGIN_MODE', "
 
    # calculate amount with leverage
    if [[ $f_type != stoploss ]] && [[ $f_type != takeprofit ]]
    then
      g_calc "${f_amount}*${LEVERAGE}"
      f_amount=$g_calc_result
    fi
  else
    # short/sell not possible in spot market
    [[ $f_side =~ ^sell$ ]] || return 1
  fi


  # Add stoploss and take profit if available
  if [ -n "$f_stoploss" ]
  then
    if [[ $f_type = limit ]]
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
    fi
    f_ccxt "print($STOCK_EXCHANGE.priceToPrecision('${f_symbol}', ${f_stoploss}))"
    f_stoploss=$f_ccxt_result
    # market or limit order with stoploss
    if [[ $f_type =~ limit|market ]] 
    then
      f_params="${f_params}'stopLoss': { 'triggerPrice': $f_stoploss, 'type': 'market'  }, "
    # stoploss (change) for open position
    elif [[ $f_type = "stoploss" ]] 
    then
      f_type="market"
      f_price=$f_stoploss
      f_params="${f_params}'reduceOnly': True, 'triggerPrice': $f_stoploss, 'triggerDirection': '$f_trigger_sl', "
    fi
  fi
  if [ -n "$f_takeprofit" ]
  then
    # check for long
    if [[ $f_type = limit ]]
    then
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
    fi
    f_ccxt "print($STOCK_EXCHANGE.priceToPrecision('${f_symbol}', ${f_takeprofit}))"
    f_takeprofit=$f_ccxt_result
    [[ $f_type =~ limit|market ]] && f_params="${f_params}'takeProfit': { 'triggerPrice': $f_takeprofit, 'type': 'limit', 'price': $f_takeprofit, }, "
    if [[ $f_type = "takeprofit" ]] 
    then
      f_type="limit"
      f_price=$f_takeprofit
      f_params="${f_params}'reduceOnly': True, 'triggerPrice': $f_takeprofit, 'triggerDirection': '$f_trigger_tp', "
    fi
  fi
 
  # end up params syntax with "}"
  f_params="${f_params}}"  

  # calculate price amount precision
  f_ccxt "print($STOCK_EXCHANGE.amountToPrecision('${f_symbol}', ${f_amount}))"
  f_amount=$f_ccxt_result
  if [[ $f_type = limit ]]
  then
    f_ccxt "print($STOCK_EXCHANGE.priceToPrecision('${f_symbol}', ${f_price}))"
    f_price=$f_ccxt_result
  fi

  # do the order
  # market order with or without stoploss/takeprofit
  [[ $f_type = limit ]] && local f_order="symbol='${f_symbol}', type='$f_type', price=$f_price, amount=${f_amount}, side='${f_side}', ${f_params}"
  [[ $f_type = market ]] && local f_order="symbol='${f_symbol}', type='$f_type', amount=${f_amount}, side='${f_side}', ${f_params}"

  # takeprofit/stoploss only
  [[ $f_params =~ reduceOnly ]] && local f_order="symbol='${f_symbol}', type='$f_type', amount=${f_amount}, side='${f_side_opposide}', price=$f_price, ${f_params}"
  echo "$f_order" | notify.sh -s "ORDER"
  f_ccxt "print($STOCK_EXCHANGE.createOrder(${f_order}))" || return 1

  # refresh orders and positions
  get_orders "$f_symbol"
  get_positions
  get_position_array
  get_orders_array
}

