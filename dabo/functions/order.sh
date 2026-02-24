#!/bin/bash

function order {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN
 
  unset f_order_result
  local f_symbol=$1 f_amount=$2 f_side=$3 f_price=$4
  
  local f_type=market
  [[ -n "$f_price" ]] && f_type=limit
  
  # Validate input
  [[ -z "$f_symbol" || -z "$f_amount" || -z "$f_side" || -z "$f_price" ]] && {
    g_echo_error "Usage: order_long symbol amount price long/short"
    return 1
  }

  # backward-compatibility with older versions (SL/TP) with order-function
  if [[ $f_price = stoploss ]]
  then
    order_stoploss "$f_symbol" "$f_amount" "$5"
    return $?
  fi
  if [[ $f_price = takeprofit ]]
  then
    order_takeprofit "$f_symbol" "$f_amount" "$5"
    return $?
  fi

  # Prepare symbol
  f_order_prepare_symbol "$f_symbol" || return 1
  f_symbol="$f_order_prepare_symbol_result"
  local f_asset="$f_order_prepare_symbol_asset"

  # Convert amount - SUPPORTS asset_amount:XXX AND currency!
  f_order_convert_amount "$f_amount" "$f_type" "$f_price" "$f_asset" || return 1
  local f_amount_final="$f_order_convert_amount_result"
  local f_currency_amount="$f_order_convert_amount_currency_result"

  # Check balance
  f_order_check_balance "$f_currency_amount" || return 1

  # Prepare leverage/margin
  f_order_prepare_leverage "$f_symbol" "$f_amount_final" "$f_type" || return 1
  f_symbol="$f_order_prepare_leverage_symbol"
  f_amount_final="$f_order_prepare_leverage_amount"

  # Apply precision
  f_order_apply_precision "$f_symbol" "$f_amount_final" "$f_price" "$f_type" || return 1
  f_amount_final="$f_order_apply_precision_amount"
  f_price_final="$f_order_apply_precision_price"

  # Check existing orders
  f_order_check_existing "$f_symbol" "$f_asset" "$f_price_final" "$f_amount_final" || return 0

  # Build order string
  [[ $f_side = long ]] && f_side="buy"
  [[ $f_side = short ]] && f_side="sell"

  local f_order="symbol='${f_symbol}', type='$f_type', amount=${f_amount_final}, side='${f_side}'"
  [[ $f_type = "limit" ]] && f_order="symbol='${f_symbol}', type='$f_type', price=$f_price_final, amount=${f_amount_final}, side='${f_side}'"

  # Execute order
  f_order_execute "$f_order" "$f_note" "$f_asset" || return 1

  # Refresh data
  get_orders "$f_symbol"
  get_positions
  get_orders_array
}

