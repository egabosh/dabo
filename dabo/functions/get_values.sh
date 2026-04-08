#!/bin/bash

# Copyright (c) 2022-2026 olli
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

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_asset f_time f_prefix f_histfile f_columns f_return f_levelsfile f_tmp_levels f_first f_lstmfilea f_rangefile ldate lside lprice lpercentage lupprice ldownprice lmedian_current_month lmedian_next_month lmedian_current_next_month_average
  
  get_asset_histfiles
  for f_histfile in ${f_asset_histfiles[@]}
  do

    # parse asset from histfile
    f_asset="${f_histfile##*/}"
    f_asset="${f_asset%.1d.csv}"
    f_asset="${f_asset%%.*}"

    # parse time from histfile
    f_time="${f_histfile%.csv}"
    f_time="${f_time##*.}"

    f_prefix="${f_time}_"

    # special on ECONOMY data
    #if [[ "$f_asset" =~ ^ECONOMY_ ]] 
    #then
    #  f_prefix="${f_asset}_${f_time}_"
    #fi
      
    f_columns="${f_prefix}date,${f_prefix}open,${f_prefix}high,${f_prefix}low,${f_prefix}close,${f_prefix}volume,${f_prefix}change,${f_prefix}ath,${f_prefix}ema12,${f_prefix}ema26,${f_prefix}ema50,${f_prefix}ema100,${f_prefix}ema200,${f_prefix}ema400,${f_prefix}ema800,${f_prefix}rsi5,${f_prefix}rsi14,${f_prefix}rsi21,${f_prefix}macd,${f_prefix}macd_ema9_signal,${f_prefix}macd_histogram,${f_prefix}macd_histogram_signal,${f_prefix}macd_histogram_max,${f_prefix}macd_histogram_strength"
    g_read_csv "${f_histfile}" 2 "$f_columns"

    # get range and fibonacci retracements with extensions
    f_rangefile="${f_histfile}.range.chart"
    if [[ -s "$f_rangefile" ]]
    then
      read f_range_lower f_range_upper <"$f_rangefile"
      vr[${f_asset}_${f_time}_range_upper]=$f_range_upper
      vr[${f_asset}_${f_time}_range_lower]=$f_range_lower
    fi
    f_fibonaccifile="${f_histfile}.range.fibonacci.chart"
    if [[ -s "$f_fibonaccifile" ]]
    then
      while read f_fibnum f_fiblevel
      do
        vr[${f_asset}_${f_time}_range_fibonacci_${f_fibnum}]=$f_fiblevel
      done <"$f_fibonaccifile"
    fi
   
    # get liquidations
    if [[ $f_time = 1h ]]
    then
      for f_liquiditytime in 12h 1d 3d
      do
        f_liquidityfile="${f_histfile}.liquidity_${f_liquiditytime}"
        if [[ -s "$f_liquidityfile" ]]
        then
          IFS=, read ldate lside lprice lpercentage lupprice ldownprice < <(tail -n 1 "$f_liquidityfile")
          vr[${f_asset}_${f_time}_liquidity_${f_liquiditytime}_date]=$ldate
          vr[${f_asset}_${f_time}_liquidity_${f_liquiditytime}_side]=$lside
          vr[${f_asset}_${f_time}_liquidity_${f_liquiditytime}_price]=$lprice
          vr[${f_asset}_${f_time}_liquidity_${f_liquiditytime}_percentage]=$lpercentage
          vr[${f_asset}_${f_time}_liquidity_${f_liquiditytime}_upprice]=$lupprice
          vr[${f_asset}_${f_time}_liquidity_${f_liquiditytime}_downprice]=$ldownprice
        fi
      done
    fi
    
    if [[ $f_time = 1d ]]
    then

      # check for month saisonality indicator/statistic
      if [[ -s "${f_histfile}.saisonality" ]]
       then
        IFS=, read ldate lmedian_current_month lmedian_next_month lmedian_current_next_month_average < <(tail -n 1 "${f_histfile}.saisonality")
        vr[${f_asset}_1M_saisonality_date]=$ldate
        vr[${f_asset}_1M_saisonality_median_current_month]=$lmedian_current_month
        vr[${f_asset}_1M_saisonality_median_next_month]=$lmedian_next_month
        vr[${f_asset}_1M_saisonality_median_current_next_month_average]=$lmedian_current_next_month_average
      fi

      # check for etf in- and outflows
      if [[ -s "${f_histfile}.etf_flows" ]]
      then
        vr[${f_asset}_7d_etf_flow]=$(tail -n 7 "${f_histfile}.etf_flows" | awk -F',' '{sum+=$3} END {printf "%.0f\n", sum}')
        vr[${f_asset}_2d_etf_flow]=$(tail -n 2 "${f_histfile}.etf_flows" | awk -F',' '{sum+=$3} END {printf "%.0f\n", sum}')
        vr[${f_asset}_7d_etf_flow_ishares]=$(tail -n 7 "${f_histfile}.etf_flows" | awk -F',' '{sum+=$2} END {printf "%.0f\n", sum}')
        vr[${f_asset}_2d_etf_flow_ishares]=$(tail -n 2 "${f_histfile}.etf_flows" | awk -F',' '{sum+=$2} END {printf "%.0f\n", sum}')
      fi

      # check for lstm prediction daily
      f_lstmfile="asset-histories/${f_histfile}.lstm_prediction"
      if [[ -s "$f_lstmfile" ]]
      then
        vr[${f_asset}_levels_${f_time}_lstm_prediction]=$(cut -d, -f2 "$f_lstmfile" | tail -n1)
      fi
    fi

    if [[ $f_time = 1w ]]
    then
      
      # check for lstm prediction weekly
      f_lstmfile="asset-histories/${f_histfile}.lstm_prediction"
      if [[ -s "$f_lstmfile" ]]
      then
        vr[${f_asset}_levels_${f_time}_lstm_prediction]=$(cut -d, -f2 "$f_lstmfile" | tail -n1)
      fi
    fi

   done

  # check for cycle top indicators 
  if [[ -s asset-histories/MARKETDATA_BTC_CYCLE_TOP_INDICATORS.history.1d.csv ]]
  then
    IFS=, read vr[MARKETDATA_BTC_CYCLE_TOP_date] vr[MARKETDATA_BTC_CYCLE_TOP_price] vr[MARKETDATA_BTC_CYCLE_TOP_picycle] vr[MARKETDATA_BTC_CYCLE_TOP_rupl] vr[MARKETDATA_BTC_CYCLE_TOP_rhodl] vr[MARKETDATA_BTC_CYCLE_TOP_puell] vr[MARKETDATA_BTC_CYCLE_TOP_2yma] vr[MARKETDATA_BTC_CYCLE_TOP_trolololo] vr[MARKETDATA_BTC_CYCLE_TOP_mvrv] vr[MARKETDATA_BTC_CYCLE_TOP_reserverisk] vr[MARKETDATA_BTC_CYCLE_TOP_woodbull] vr[MARKETDATA_BTC_CYCLE_TOP_confidence] < <(tail -n 1 "asset-histories/MARKETDATA_BTC_CYCLE_TOP_INDICATORS.history.1d.csv")
  fi

  # read m2_3_month_dely from file
  if [[ -s asset-histories/MARKETDATA_US_FED_M2_NS_MONEY_SUPPLY_3_MONTH_DELAY.history.1M.csv ]]
  then
    IFS=, read vr[m2_3_month_delay_date] vr[m2_3_month_delay] < <(tail -n 1 "asset-histories/MARKETDATA_US_FED_M2_NS_MONEY_SUPPLY_3_MONTH_DELAY.history.1M.csv")
  fi

  # use reverse as default to be 0 latest, 1 pre latest,...
  unset v
  declare -Ag v
  for key in "${!vr[@]}"
  do
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

