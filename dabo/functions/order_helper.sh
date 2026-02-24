#!/bin/bash

# Helper functions for order functions

function f_order_prepare_symbol {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_input_symbol=$1
  local f_symbol f_asset
  
  # Format symbol: XXX/$CURRENCY[:$CURRENCY]
  if ! [[ $f_input_symbol =~ /$CURRENCY ]]
  then
    f_symbol=${f_input_symbol%$CURRENCY}
    f_symbol=${f_symbol}/${CURRENCY}
    [[ -n "$LEVERAGE" ]] && f_symbol="${f_symbol}:${CURRENCY}"
  else
    f_symbol="$f_input_symbol"
  fi
  
  # Extract asset and remove backslashes (clean!)
  f_asset="${f_symbol//:$CURRENCY/}"
  f_asset="${f_asset//\//}"  # Clean backslash removal
  
  f_order_prepare_symbol_result="$f_symbol"
  f_order_prepare_symbol_asset="$f_asset"
}

function f_order_convert_amount {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_amount=$1 f_type=$2 f_price=$3 f_asset=$4
  local f_converted_amount
  
  # SUPPORTS BOTH asset_amount:XXX AND currency amounts!
  if [[ $f_amount =~ ^asset_amount: ]]
  then
    f_converted_amount="${f_amount#asset_amount:}"
    local f_target_asset="${f_asset%$CURRENCY}"
    currency_converter "$f_amount" "$f_target_asset" "$CURRENCY" || return 1
    f_order_convert_amount_currency_result="$f_currency_converter_result"
  else
    f_order_convert_amount_currency_result=${f_amount}
    if [[ $f_type = "market" ]]
    then
      # Market order: use current price
      local f_target_asset="${f_asset%$CURRENCY}"
      currency_converter "$f_amount" "$CURRENCY" "$f_target_asset" || return 1
      f_converted_amount="$f_currency_converter_result"
    elif [[ $f_type = "limit" ]]
    then
      # Limit order: use limit price
      g_calc "1/${f_price}*${f_amount}"
      f_converted_amount="$g_calc_result"
    fi
    if [[ -n "$LEVERAGE" ]]
    then
      g_calc "${f_converted_amount}*${LEVERAGE}"
      f_converted_amount="$g_calc_result"
    fi
  fi
  
  f_order_convert_amount_result="$f_converted_amount"
}

function f_order_check_balance {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_currency_amount=$1 
  #f_asset=$2
  #local f_amount_currency
  
  # Convert asset amount back to currency for balance check
  #local f_target_asset="${f_asset%$CURRENCY}"
  #currency_converter "$f_amount" "$f_target_asset" "$CURRENCY" || return 1
  #f_amount_currency="$f_currency_converter_result"
  
  get_balance
  
  if g_num_is_higher "$f_currency_amount" "$f_CURRENCY_BALANCE"
  then
    g_echo_warn "Not enough Balance ($f_CURRENCY_BALANCE). Requested: $f_currency_amount"
    return 1
  fi
}

function f_order_prepare_leverage {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_symbol=$1 f_amount=$2 f_type=$3 
  local f_params f_final_amount="$f_amount"
  
  # Ensure swap symbol format
  [[ $f_symbol =~ : ]] || f_symbol="${f_symbol}:${CURRENCY}"
  
  # Set position mode
  [[ $STOCK_EXCHANGE = phemex ]] && f_ccxt "$STOCK_EXCHANGE.setPositionMode(hedged=False, symbol='$f_symbol')"
  
  # Set leverage
  f_ccxt "$STOCK_EXCHANGE.setLeverage($LEVERAGE, '$f_symbol')" || return 1
  
  ## Add margin mode
  f_ccxt "$STOCK_EXCHANGE.set_margin_mode('isolated', '${f_symbol}')" || return 1
  #f_params="params={'marginMode': '$MARGIN_MODE', }"
  
  # Multiply amount by leverage (only for new positions)
  if [[ $f_type != "stoploss" && $f_type != "takeprofit" ]]
  then
    g_calc "${f_amount}*${LEVERAGE}"
    f_final_amount="$g_calc_result"
  fi
  
  f_order_prepare_leverage_symbol="$f_symbol"
  f_order_prepare_leverage_amount="$f_final_amount"
  f_order_prepare_leverage_params="$f_params"
}

function f_order_apply_precision {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_symbol=$1 f_amount=$2 f_price=$3 f_type=$4
  
  # Apply amount precision
  f_ccxt "print($STOCK_EXCHANGE.amountToPrecision('${f_symbol}', ${f_amount}))"
  local f_amount_prec="$f_ccxt_result"
  
  # Apply price precision (only for limit orders)
  local f_price_prec="$f_price"
  if [[ $f_type = "limit" ]]
  then
    f_ccxt "print($STOCK_EXCHANGE.priceToPrecision('${f_symbol}', ${f_price}))"
    f_price_prec="$f_ccxt_result"
  fi
  
  f_order_apply_precision_amount="$f_amount_prec"
  f_order_apply_precision_price="$f_price_prec"
}

function f_order_check_existing {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_symbol=$1 f_asset=$2 f_price=$3 f_amount=$4
  local f_orderid
  
  get_orders "$f_symbol"
  get_orders_array
  
  if [[ -z "${o[${f_asset}_ids]}" ]]
  then
    sleep 1
    get_orders "$f_symbol"
    get_orders_array
  fi
  
  for f_orderid in ${o[${f_asset}_ids]}
  do
    if g_num_is_approx "${o[${f_asset}_${f_orderid}_entry_price]}" "$f_price" 0.7 0.7
    then
      if g_num_is_approx "${o[${f_asset}_${f_orderid}_amount]}" "$f_amount" 10 10
      then
        g_echo_note "Order already exists: ${o[${f_asset}_${f_orderid}_id]}"
        return 1
      else
        g_echo_note "Cancelling existing order with different amount"
        order_cancel_id "$f_asset" "${o[${f_asset}_${f_orderid}_id]}" force
        break
      fi
    fi
  done
}

function f_order_execute {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_order=$1 f_note=$2 f_asset=$3
  
  # Execute order
  if ! f_ccxt "print($STOCK_EXCHANGE.createOrder(${f_order}))"
  then
    g_echo_error "$f_asset ORDER FAILED! $f_ccxt_result"
    return 1
  fi

  # Store JSON result in array
  declare -Ag f_order_result
  for f_key in "${!g_json[@]}"
  do
    [[ $f_key == info.* ]] && continue
    f_order_result[$f_key]="${g_json[$f_key]}"
  done  

  g_echo_ok "$f_asset ORDER SUCCEEDED! ID: ${f_order_result[id]}"
  
  # Notify with sorted results
  for f_key in "${!f_order_result[@]}"
  do
    echo "\${f_order_result[$f_key]}=${f_order_result[$f_key]}"
  done | sort | notify.sh -s "ORDER $f_note ($f_order)"
}

