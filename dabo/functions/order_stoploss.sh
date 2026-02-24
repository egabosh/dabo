#!/bin/bash

function order_stoploss {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN
 
  unset f_order_result
  local f_symbol=$1 f_amount=$2 f_stoploss=$3 f_note="${4:-}"
  
  # Validate input
  [[ -z "$f_symbol" || -z "$f_amount" || -z "$f_stoploss" ]] && {
    g_echo_error "Usage: order_stoploss symbol amount stoploss_price [note]"
    return 1
  }

  # Prepare symbol
  f_order_prepare_symbol "$f_symbol" || return 1
  f_symbol="$f_order_prepare_symbol_result"
  local f_asset="$f_order_prepare_symbol_asset"

  # Apply precision to stoploss price
  f_ccxt "print($STOCK_EXCHANGE.priceToPrecision('${f_symbol}', ${f_stoploss}))"
  local f_sl_price="$f_ccxt_result"

  # Get current position side to determine opposite side
  get_positions "$f_symbol"
  local f_pos_side=${p[${f_asset}_side]}
  [[ -n "$f_pos_side" ]] || { g_echo_error "No position found for $f_asset"; return 1; }

  # Determine opposite side and trigger direction
  local f_side=$([[ "$f_pos_side" = "Long" ]] && echo "sell" || echo "buy")
  local f_trigger_direction=$([[ "$f_pos_side" = "Long" ]] && echo "up" || echo "down")

  # convert to asset amount if not
  f_order_convert_amount $f_amount
  f_amount=$f_order_convert_amount_result

  # Apply precision
  f_order_apply_precision "$f_symbol" "$f_amount" "$f_sl_price" "market" || return 1
  f_amount_final="$f_order_apply_precision_amount"

  # check for existing/similar order
  f_order_check_existing "$f_symbol" "$f_asset" "$f_sl_price" "$f_amount" || return 0

  # Build stoploss order params
  #local f_params="params={'reduceOnly': True, 'triggerPrice': $f_sl_price, 'triggerDirection': '$f_trigger_direction'}"
  #local f_order="symbol='${f_symbol}', type='market', amount=${f_amount_final}, side='${f_side}', ${f_params}"
  f_order="'${f_symbol}', 'STOP_MARKET', 'null', ${f_amount_final}, null, {'stopPrice': ${f_sl_price}, 'reduceOnly': True, 'timeInForce': 'GTC'}"


  # Check existing orders (simplified for SL)
  get_orders "$f_symbol"
  get_orders_array

  # Execute order
  f_order_execute "$f_order" "$f_note" "$f_asset" || return 1

  # Refresh orders
  get_orders "$f_symbol"
  get_orders_array
}

