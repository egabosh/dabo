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


# Example strategy

g_echo_note "EXAMPLE Strategy"

##### WARNING! This strategy is only intended as an example and should not be used with real trades. Please develop your own strategy ######

# if you want to use this remove the next line with return 0
return 0

# reset score
unset s_score
unset s_score_hist
s_score=0


### BEGIN market scoring ###
# correlation to crypto
for asset in DOWJONES SP500 NASDAQ MSCIEAFE GOLD MSCIWORLD KRE
do

  g_echo "scoring ECONOMY_${asset}"

  # bullish? bull market?
  [ -n "${v[ECONOMY_${asset}_1d_ema200_0]}" ] && if g_num_is_higher ${v[ECONOMY_${asset}_15m_close_0]} ${v[ECONOMY_${asset}_1d_ema200_0]}
  then
    score 2 "${asset} EMA200 over last 15m close"
  else
    score -2 "${asset} EMA200 under last 15m close"
  fi
  
  # RSI14 1d
  if [ -n "${v[ECONOMY_${asset}_1d_rsi14_0]}" ]
  then
    rsi14=${v[ECONOMY_${asset}_1d_rsi14_0]}
    g_num_is_between $rsi14 80 100 && score -2 "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 55 80  && score  2 "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 15 45  && score  1 "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 0  15  && score -2 "${asset} RSI14 $rsi14"
  fi
  
  # macd trend
  [[ ${v[ECONOMY_${asset}_1d_macd_histogram_signal_0]} = uptrend ]]   && score  2 "${asset} MACD uptrend"
  [[ ${v[ECONOMY_${asset}_1d_macd_histogram_signal_0]} = downtrend ]] && score -2 "${asset} MACD downtrend"
  
done

# inverse correlation to crypto
for asset in DXY OILGAS
do

  g_echo "scoring ECONOMY_${asset}"

  # bullish? bull market?
  [ -n "${v[ECONOMY_${asset}_1d_ema200_0]}" ] && if g_num_is_higher ${v[ECONOMY_${asset}_15m_close_0]} ${v[ECONOMY_${asset}_1d_ema200_0]}
  then
    score -2 "${asset} EMA200 over last 15m close"
  else
    score 2 "${asset} EMA200 under last 15m close"
  fi

  # RSI14 1d
  if [ -n "${v[ECONOMY_${asset}_1d_rsi14_0]}" ]
  then
    rsi14=${v[ECONOMY_${asset}_1d_rsi14_0]}
    g_num_is_between $rsi14 80 100 && score 2  "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 55 80  && score -2 "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 15 45  && score -1 "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 0  15  && score 2  "${asset} RSI14 $rsi14"
  fi

  # macd trend
  [[ ${v[ECONOMY_${asset}_1d_macd_histogram_signal_0]} = uptrend ]]   && score -2 "${asset} MACD uptrend"
  [[ ${v[ECONOMY_${asset}_1d_macd_histogram_signal_0]} = downtrend ]] && score 2  "${asset} MACD downtrend"

done

### Evaluate BTC and ETH
for asset in BTC${CURRENCY} ETH${CURRENCY}
do

  g_echo "scoring ${asset}"

  # bullish? bull market?
  [ -n "${v[${asset}_1d_ema200_0]}" ] && if g_num_is_higher ${v[${asset}_15m_close_0]} ${v[${asset}_1d_ema200_0]}
  then
    score  2 "${asset} EMA200 over last 15m close"
  else
    score -2 "${asset} EMA200 under last 15m close"
  fi

  # RSI14 1d
  if [ -n "${v[${asset}_1d_rsi14_0]}" ]
  then
    rsi14=${v[${asset}_1d_rsi14_0]}
    g_num_is_between $rsi14 80 100 && score -2 "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 55 80  && score  2 "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 15 45  && score  1 "${asset} RSI14 $rsi14"
    g_num_is_between $rsi14 0  15  && score -2 "${asset} RSI14 $rsi14"
  fi
  
  # macd trend
  [[ ${v[${asset}_1d_macd_histogram_signal_0]} = uptrend ]]   && score  2 "${asset} MACD uptrend"
  [[ ${v[${asset}_1d_macd_histogram_signal_0]} = downtrend ]] && score -2 "${asset} MACD downtrend"

done

### END market scoring ###

# save score until here
market_score=$s_score
market_score_hist=$s_score_hist

### Go through trading symbols
for symbol in ${f_symbols_array_trade[@]}
do

  # restore market score as base
  s_score=$market_score
  s_score_hist=$market_score_hist

  asset=${symbol//:$CURRENCY/}
  asset=${asset//\//}

  ### Evaluate symbol
  g_echo "scoring ${asset}"

  # bullish? bull market?
  [ -n "${v[${asset}_1d_ema200_0]}" ] && if g_num_is_higher ${v[${asset}_15m_close_0]} ${v[${asset}_1d_ema200_0]}
  then
    score  2 "${asset} EMA200 over last 15m close"
  else
    score -2 "${asset} EMA200 under last 15m close"
  fi

  # RSI14 5m
  if [ -n "${v[${asset}_5m_rsi14_0]}" ]
  then
    rsi14=${v[${asset}_5m_rsi14_0]}
    g_num_is_between $rsi14 80 100 && score -4 "$asset RSI14 $rsi14"
    g_num_is_between $rsi14 55 80  && score  4 "$asset RSI14 $rsi14"
    g_num_is_between $rsi14 15 45  && score  2 "$asset RSI14 $rsi14"
    g_num_is_between $rsi14 0  15  && score -4 "$asset RSI14 $rsi14"
  fi

  # macd trend
  [[ ${v[${asset}_5m_macd_histogram_signal_0]} = uptrend ]]   && score  2 "$asset MACD uptrend"
  [[ ${v[${asset}_5m_macd_histogram_signal_0]} = downtrend ]] && score -2 "$asset MACD downtrend"
  

  # go short or go long or better do notghing?
  side="unclear"
  g_num_is_higher $s_score 5 && side="long"
  g_num_is_lower $s_score -5 && side="short"
  
  g_echo_ok "Score: $s_score"
  g_echo_ok "Side: $side"
  g_echo "Scores: $s_score_hist"
    
  # remove existing orders and do nothing if unclear
  if [[ $side = "unclear" ]]
  then
    g_echo "Situation of $asset unclear - remove existing orders and do nothing!"
    order_cancel "$symbol"
    continue
  fi

  # if no contract trading / no shot possible ignore
  if [ -z "$LEVERAGE" ] && [[ $side = short ]] 
  then
    g_echo "No 'short' possible while sport trading - doung nothing with $asset"
    continue
  fi

  # Next week level is:
  g_echo "level_1w_next_up: ${v[${asset}_levels_1w_next_up]}"
  g_echo "level_1w_next_down: ${v[${asset}_levels_1w_next_down]}"
  
  # define entry price
  unset entry_price
  [[ $side = long ]] && entry_price=${v[${asset}_levels_1w_next_down]}
  [[ $side = short ]] && entry_price=${v[${asset}_levels_1w_next_up]}

  # if entry price not given set to current price
  [ -z "$entry_price" ] && entry_price=${v[${asset}_price]}

  # check for updates if order with entry price is already defined
  if [ -n "${o[${asset}_open_${side}_entry_price]}" ]
  then
    if g_num_is_approx ${o[${asset}_open_${side}_entry_price]} $entry_price 0.5 0.5 
    then
      g_echo "Order of $asset at ${o[${asset}_open_${side}_entry_price]} fine"
    else
      # cancelling order
      g_echo_warn "Cancelling order because entry price not seems to be up2date anymore: ${o[${asset}_open_${side}_entry_price]} != $entry_price"
      order_cancel "$symbol"
    fi
  fi
  
  # check for already existing order
  if [ -n "${o[${asset}_present]}" ]
  then
    g_echo_ok "Order(s) of ${asset} already exists"
    continue
  fi

  # check for already existing position 
  if [ -n "${p[${asset}_currency_amount]}" ]
  then
    g_echo "Position of ${asset} already open"
    continue
  fi

  # StopLoss at 20% loss
  stoplosspercentage=20
  # calc percentage loss if leverage is set
  if [ -n "$LEVERAGE" ]
  then
    g_calc "$stoplosspercentage/$LEVERAGE"
    stoplosspercentage=$g_calc_result
  fi
  # calc stoploss
  [[ $side = long ]] &&  g_calc "$entry_price-($entry_price/100*${stoplosspercentage})"
  [[ $side = short ]] && g_calc "$entry_price+($entry_price/100*${stoplosspercentage})"
  stoploss=$g_calc_result

  # TakeProfit at 2% profit
  takeprofitpercentage=5
  if [ -n "$LEVERAGE" ]
  then
    g_calc "$takeprofitpercentage/$LEVERAGE"
    takeprofitpercentage=$g_calc_result
  fi
  [[ $side = long ]] &&  g_calc "$entry_price+($entry_price/100*${takeprofitpercentage})"
  [[ $side = short ]] && g_calc "$entry_price-($entry_price/100*${takeprofitpercentage})"
  takeprofit=$g_calc_result

  # Use 100 of balace for trade
  trade_balance=100
  # altarnative calculate 2 percentage of available balace for trade
  #get_balance
  #g_calc "$f_CURRENCY_BALANCE/100*2"
  #trade_balance=$g_calc_result

  # place the order
  order "$symbol" "$trade_balance" "$side" "$entry_price" "$stoploss" "$takeprofit"
 
done

