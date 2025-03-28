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


function get_values {
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_assets="$@"
  local f_asset_histories

  f_assets=${f_assets//:$CURRENCY/}
  f_assets=${f_assets//\//}

  for f_asset in $f_assets
  do
    f_asset_histories+="$f_asset "
    f_asset_histories+="MARKETDATA_BINANCE_OPEN_INTEREST_$f_asset "
    f_asset_histories+="MARKETDATA_BINANCE_LONG_SHORT_RATIO_TAKER_$f_asset "
    f_asset_histories+="MARKETDATA_BINANCE_LONG_SHORT_RATIO_ACCOUNT_$f_asset "
  done

  local f_eco_asset f_eco_assets f_asset f_time f_prefix f_histfile f_columns f_return f_levelsfile f_tmp_levels f_first f_lstmfile
  
  for f_eco_asset in $ECO_ASSETS
  do
    if [ -z "$f_eco_assets" ]
    then
      f_eco_assets="ECONOMY-${f_eco_asset}"
    else
      f_eco_assets="$f_eco_assets ECONOMY-${f_eco_asset}"
    fi
  done
  
  # get current prices from exchange
  get_symbols_ticker
  # get values from csv files
  
  for f_asset in $f_asset_histories\
   BTC${CURRENCY}\
   $f_eco_assets\
   MARKETDATA_BINANCE_OPEN_INTEREST_BTC${CURRENCY}\
   MARKETDATA_BINANCE_LONG_SHORT_RATIO_TAKER_BTC${CURRENCY}\
   MARKETDATA_BINANCE_LONG_SHORT_RATIO_ACCOUNT_BTC${CURRENCY}\
   MARKETDATA_FEAR_AND_GREED_ALTERNATIVEME\
   MARKETDATA_FEAR_AND_GREED_CNN\
   MARKETDATA_US_CONSUMER_PRICE_INDEX_CPI\
   MARKETDATA_US_FED_FUNDS_RATE MARKETDATA_US_UNEMPLOYMENT_RATE
  do

    # read latest ohlcv data and indicators per timeframe to vars
    for f_time in 5m 15m 1h 4h 1d 1w
    do
      # special on ECONOMY data
      f_prefix="${f_time}_"
      if [[ "$f_asset" =~ ^ECONOMY- ]] 
      then
        f_prefix="${f_asset}_${f_time}_"
        f_prefix=${f_prefix//-/_}
      fi
      
      # histfile
      f_histfile="asset-histories/${f_asset}.history.${f_time}.csv"
      if ! [ -s "$f_histfile" ]
      then
        f_return=1
        continue
      fi
      f_columns="${f_prefix}date,${f_prefix}open,${f_prefix}high,${f_prefix}low,${f_prefix}close,${f_prefix}volume,${f_prefix}change,${f_prefix}ath,${f_prefix}ema12,${f_prefix}ema26,${f_prefix}ema50,${f_prefix}ema100,${f_prefix}ema200,${f_prefix}ema400,${f_prefix}ema800,${f_prefix}rsi5,${f_prefix}rsi14,${f_prefix}rsi21,${f_prefix}macd,${f_prefix}macd_ema9_signal,${f_prefix}macd_histogram,${f_prefix}macd_histogram_signal,${f_prefix}macd_histogram_max,${f_prefix}macd_histogram_strength"
      g_read_csv "${f_histfile}" 2 "$f_columns"
    done

    # read current levels
    for f_time in 1w 1d
    do
      f_levelsfile="asset-histories/${f_asset}.history.${f_time}.csv.levels"
      if [ -s "$f_levelsfile" ] 
      then
        # get levels
        read -r -a f_levels <"$f_levelsfile"
        vr[${f_asset}_levels_$f_time]="${f_levels[*]}"
        
        # add current price and sort
        f_levels+=("${vr[${f_asset}_price]}")
        oldIFS="$IFS"
        IFS=$'\n' f_levels_sorted=($(sort -n <<<"${f_levels[*]}"))
        IFS="$oldIFS"
        
        # find current price and +- one for upper lower price
        for ((i=0; i<${#f_levels_sorted[@]}; i++)); do
          if [ "${f_levels_sorted[$i]}" = "${vr[${f_asset}_price]}" ]
          then
            vr[${f_asset}_levels_${f_time}_next_up]=${f_levels_sorted[i+1]}
            vr[${f_asset}_levels_${f_time}_next_down]=${f_levels_sorted[i-1]}
            break
          fi
        done
      fi

      f_lstmfile="asset-histories/${f_asset}.history.${f_time}.lstm_prediction.csv"
      if [ -s "$f_lstmfile" ] 
      then
        vr[${f_asset}_levels_${f_time}_lstm_prediction]=$(cut -d, -f2 "$f_lstmfile" | tail -n1)
      fi
      
    done
  done

  # use reverse as default to be 0 latest, 1 pre latest,...
  unset v
  declare -Ag v
  for key in "${!vr[@]}"; do
    v[$key]=${vr[$key]}
  done
  unset vr

  # write values file for overview
  for i in "${!v[@]}"
  do 
    echo "\${v[$i]}=${v[$i]}"
  done | sort >values.new
  mv values.new values

  return $f_return
}

