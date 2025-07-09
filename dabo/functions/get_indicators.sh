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


function get_indicators_all {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
 
  local f_last_intervals="$1"
  
  local f_histfile f_symbol

  # ECONOMY and MARKETDATA
  find asset-histories -maxdepth 1 -name "ECONOMY-*.history.[0-5][5dhwmM]*.csv" -o -name "MARKETDATA_*.history.[0-5][5dhwmM]*.csv" | sort | while read f_histfile
  do
    if [[ -s "${f_histfile}.fetching" ]] || [[ -s "${f_histfile}.indicators-calculating" ]] 
    then
      g_echo_note "Fetching/Indicators-calculating already active on ${f_histfile}"
      continue
    fi

    # do the job
    printf "$0 %(%Y-%m-%d %H:%M:%S)T" >"${f_histfile}.indicators-calculating"
    get_indicators "${f_histfile}" ${f_last_intervals} && printf "$0 %(%Y-%m-%d %H:%M:%S)T\n" >>"$f_histfile.indicators-calculated"
    # add missing intervals for example from weekends from non-24h-assets like economic data - interval from filename
    #f_add_missing_ohlcv_intervals "${f_histfile}"
    rm -f "${f_histfile}.indicators-calculating"
  done

  shopt -s nullglob
  # find all history files of traded symbols
  get_symbols_ticker
  for f_symbol in "${f_symbols_array_trade[@]}"
  do
    f_symbol=${f_symbol%%:*}
    f_symbol=${f_symbol//\/}
    
    for f_histfile in "asset-histories/${f_symbol}.history."[145][dhwm].csv "asset-histories/${f_symbol}.history."15m.csv
    do
      if [[ -s "$f_histfile" ]] 
      then
        # check for already running jobs
        if [[ -s "${f_histfile}.fetching" ]] || [[ -s "${f_histfile}.indicators-calculating" ]] 
        then
          g_echo_note "Fetching/Indicators-calculating active on ${f_histfile}"
          continue
        fi
      
        # do the job
        printf "$0 %(%Y-%m-%d %H:%M:%S)T" >"${f_histfile}.indicators-calculating"
        get_indicators "${f_histfile}" ${f_last_intervals} && printf "$0 %(%Y-%m-%d %H:%M:%S)T\n" >>"$f_histfile.indicators-calculated"
        rm -f "${f_histfile}.indicators-calculating"

      fi
    done
  done
  shopt -u nullglob
}


function get_indicators {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_histfile="$1"
  local f_last_intervals="$2"
  # max 8928 for large files (~1 month in 5m interval; ~24 years in 1d interval)
  [[ -z $f_last_intervals ]] && f_last_intervals=8928
  [[ $f_last_intervals -gt 8928 ]] && f_last_intervals=8928
  local f_fill_missing_ohlcv_intervals=$3
  local f_line 

  # check if the job is already done
  if ! tail -n $f_last_intervals "${f_histfile}" | egrep -vq "^([0-9]){4}-([0-9]){2}-([0-9]){2}.*,([0-9\.]+,){5}[0-9\.\-]+,([0-9\.]+,){11}([0-9\.\-]+,){3}[a-z]*(,[0-9\.\-]+){2}" 
  then
    g_echo_note "${f_histfile} seems to be indicator-complete for the last ($f_last_intervals) intervals"
    return 0
  fi
  
  # history
  local f_columns="date,open,high,low,close,volume,change,ath,ema12,ema26,ema50,ema100,ema200,ema400,ema800,rsi5,rsi14,rsi21,macd,macd_ema9_signal,macd_histogram,macd_histogram_signal,macd_histogram_max,macd_histogram_strength"
  local f_emas="12 26 50 100 200 400 800"
  local f_rsis="5 14 21"
  local f_ema f_change f_changed f_line f_valid_data f_ath f_last_year f_check_var
  local f_columns_space="${f_columns//,/ }"
  g_read_csv "${f_histfile}" "${f_last_intervals}" "$f_columns"
  for ((i=0; i<=${#g_csv_array[@]}-1; i++))
  do

    # check vars
    if ! [[ "${v_csv_array_associative[date_${i}]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]
    then
      g_echo_warn "No valid date $f_histfile:${v_csv_array_associative[date_${i}]} - stopping here"
      return 1
    fi
    if ! g_num_valid_number "${v_csv_array_associative[open_${i}]}"
    then
      g_echo_warn "No Open data $f_histfile:${v_csv_array_associative[date_${i}]} - stopping here"
      return 1
    fi


    #g_echo_note "=== $0 for $f_histfile:${v_csv_array_associative[date_${i}]},$f_histfile:${v_csv_array_associative[close_${i}]}"

    # get previous position
    p=$((i-1))    

    ### check for unfilled fields
    f_change=""

    # fix olhc data
    if [[ -z "${v_csv_array_associative[high_${i}]}" ]] && [[ -z "${v_csv_array_associative[low_${i}]}" ]] && [[ -z "${v_csv_array_associative[close_${i}]}" ]] 
    then
      g_echo_note "fixing OHLC Data"
      # close is open
      v_csv_array_associative[close_${i}]=${v_csv_array_associative[open_${i}]}
      # open is previous close
      [[ -n "${v_csv_array_associative[close_${p}]}" ]]  && v_csv_array_associative[open_${i}]="${v_csv_array_associative[close_${p}]}"
      # calc high/low from open/close 
      if g_num_is_higher_equal ${v_csv_array_associative[open_${i}]}  ${v_csv_array_associative[close_${i}]}
      then
        v_csv_array_associative[high_${i}]=${v_csv_array_associative[open_${i}]}
        v_csv_array_associative[low_${i}]=${v_csv_array_associative[close_${i}]}
      else
        v_csv_array_associative[high_${i}]=${v_csv_array_associative[close_${i}]}
        v_csv_array_associative[low_${i}]=${v_csv_array_associative[open_${i}]}
      fi
      f_change=1
    fi
    
    # check ohlc data
    if ! g_num_valid_number "${v_csv_array_associative[open_${i}]}" "${v_csv_array_associative[high_${i}]}" "${v_csv_array_associative[low_${i}]}" "${v_csv_array_associative[close_${i}]}"
    then
      g_echo_warn "OHLC data incomplete $f_histfile:${v_csv_array_associative[date_${i}]} - stopping here"
      return 1
    fi

    # check for missing percentage change
    if [[ -z "${v_csv_array_associative[change_${i}]}" ]] 
    then
      # special for changes watched per year like CPI,...
      if [[ $f_histfile = "asset-histories/MARKETDATA_US_CONSUMER_PRICE_INDEX_CPI.history.1d.csv" ]] || \
       [[ $f_histfile = "asset-histories/MARKETDATA_US_UNEMPLOYMENT_RATE.history.1d.csv" ]]
      then
        if [[ $i -ge 12 ]] 
        then
          f_last_year=$((i-12))
          g_percentage-diff ${v_csv_array_associative[open_${f_last_year}]} ${v_csv_array_associative[close_${i}]}
          v_csv_array_associative[year_change_${i}]=${g_percentage_diff_result}
        fi
      fi
      g_percentage-diff ${v_csv_array_associative[open_${i}]} ${v_csv_array_associative[close_${i}]} && f_change=1
      v_csv_array_associative[change_${i}]=${g_percentage_diff_result}
    fi
    
    # ath (all-time-high) of present data
    if [[ -z "${v_csv_array_associative[ath_${i}]}" ]]
    then
      if [[ -z "${v_csv_array_associative[ath_${p}]}" ]] 
      then
        # define max for the first time 
        v_csv_array_associative[ath_${i}]=${v_csv_array_associative[high_${i}]}
      else
        if g_num_is_higher ${v_csv_array_associative[high_${i}]} ${v_csv_array_associative[ath_${p}]}
        then
          v_csv_array_associative[ath_${i}]=${v_csv_array_associative[high_${i}]}
        else
          v_csv_array_associative[ath_${i}]=${v_csv_array_associative[ath_${p}]}
        fi
      fi
      f_change=1
    fi

    # check for missing EMAs
    for f_ema_column in $f_emas
    do
      # check for enough values/lines to calculate EMA if no previous EMA given
      if [[ -z "${v_csv_array_associative[ema${f_ema_column}_${p}]}" ]] 
      then
        if ! [[ $i -ge $f_ema_column ]]  
        then
          #echo "not enough lines $i -ge $f_ema_column"
          continue
        fi
      fi
      # calculate EMA
      if [[ -z "${v_csv_array_associative[ema${f_ema_column}_${i}]}" ]]  
      then
        calc_ema ${f_ema_column} close && f_change=1
      fi
    done

    # check for missing RSI
    for f_rsi_column in $f_rsis
    do
      # check for enough values/lines to calculate RSI
      [[ $i -ge $f_rsi_column ]]  || continue
      # calculate RSI
      [[ -z "${v_csv_array_associative[rsi${f_rsi_column}_${i}]}" ]]  && calc_rsi ${f_rsi_column} change && f_change=1
      [[ ${v_csv_array_associative[rsi${f_rsi_column}_${i}]} = 0 ]]  && calc_rsi ${f_rsi_column} change && f_change=1
    done

    # check for missing macd
    [[ $i -ge 26 ]] && [[ -z "${v_csv_array_associative[macd_${i}]}" ]]  && calc_macd && f_change=1

    # write to file if change is provided
    if [[ -n "$f_change" ]] 
    then
      # find line by date
      f_line_date="${v_csv_array_associative[date_${i}]}"
      oldIFS=$IFS
      IFS=,
      f_line=""
      # build line
      for f_column in $f_columns
      do
        # special for changes watched per year like CPI,...
        if [[ $f_column = change ]]
        then
          [[ -n "${v_csv_array_associative[year_change_${i}]}" ]]  && v_csv_array_associative[change_${i}]=${v_csv_array_associative[year_change_${i}]}
        fi
        if [[ -z "$f_line" ]] 
        then
          f_line="${v_csv_array_associative[${f_column}_${i}]}"
        else
          f_line="$f_line,${v_csv_array_associative[${f_column}_${i}]}"
        fi
      done
      g_echo_note "Changing values with date ${v_csv_array_associative[date_${i}]} in \"${f_histfile}\""
      # replace line by date
      sed -i "s/$f_line_date,.*/$f_line/" "$f_histfile"
      IFS=$oldIFS
    fi


  done
  
  # cleanup large arrays
  unset v vr v_csv_array_associative v_csv_array_associative_reverse 


}

