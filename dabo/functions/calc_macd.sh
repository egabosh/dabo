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


function calc_macd {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  # - needs array ${v_csv_array_associative} for example from g_read_csv
  # - needs $i as position
  # - needs $p as previous position

  local f_period=$1  # integer!
  local f_ema12=$2  # ema12 - if not given "${v_csv_array_associative[ema12_${f_position}]}" is used
  local f_ema26=$3  # ema26 - if not given "${v_csv_array_associative[ema26_${f_position}]}" is used
  local f_target_column=$4  # column with previus RSIs - if not given "rsi$f_period" is used

  local f_position=$i  # position

  # check if there is a position (i from loop through array)
  [[ -z "$f_position" ]]  && return 1

  # check for EMA12 and 26 
  [[ -z "$f_ema12" ]]  && f_ema12="${v_csv_array_associative[ema12_${f_position}]}"
  [[ -z "$f_ema12" ]]  && return 2
  [[ -z "$f_ema26" ]]  && f_ema26="${v_csv_array_associative[ema26_${f_position}]}"
  [[ -z "$f_ema26" ]]  && return 3

  # get rsi column
  [[ -z "$f_target_column" ]]  && f_target_column="macd"

  local f_macd f_macd_ema9_signal f_macd_signal f_macd_histogram_relation f_macd_histogram f_macd_histogram_max f_macd_histogram_strength

  g_calc "${f_ema12}-${f_ema26}"
  f_macd=$g_calc_result
  v_csv_array_associative[macd_${f_position}]=$g_calc_result

  # calc MACD Signal
  calc_ema 9 macd macd_ema9_signal 
  [[ -z "${v_csv_array_associative[macd_ema9_signal_${f_position}]}" ]]  && return 5
  f_macd_ema9_signal=${v_csv_array_associative[macd_ema9_signal_${f_position}]}
  
  # calc MACD Histogram
  g_calc "${f_macd}-(${f_macd_ema9_signal})"
  f_macd_histogram=$g_calc_result
  v_csv_array_associative[macd_histogram_${f_position}]=$g_calc_result

  # check for MACD signal up- or downtrend and buy or sell if switched histogram from - to + or + to -
  f_last_histogram=${v_csv_array_associative[macd_histogram_${p}]}
  if [[ -n "$f_last_histogram" ]] 
  then
    f_macd_signal=uptrend
    [[ $f_macd_histogram =~ ^- ]] && f_macd_signal=downtrend
    [[ $f_macd_histogram =~ ^- ]] && [[ $f_last_histogram =~ ^[0-9] ]] && f_macd_signal=sell
    [[ $f_macd_histogram =~ ^[0-9] ]] && [[ $f_last_histogram =~ ^- ]] && f_macd_signal=buy
    v_csv_array_associative[macd_histogram_signal_${f_position}]=$f_macd_signal
  fi

  # check if there is a new macd max value to calculate the strength of the trend
  f_macd_histogram_positive=${f_macd_histogram//-/}
  f_macd_histogram_max=${v_csv_array_associative[macd_histogram_max_${p}]}
  if [[ -z "$f_macd_histogram_max" ]] 
  then
    # define max for the first time 
    v_csv_array_associative[macd_histogram_max_${f_position}]=$f_macd_histogram_positive
    f_macd_histogram_max=$f_macd_histogram_positive
  else
    if g_num_is_higher $f_macd_histogram_positive $f_macd_histogram_max
    then
      v_csv_array_associative[macd_histogram_max_${f_position}]=$f_macd_histogram_positive
      f_macd_histogram_max=$f_macd_histogram_positive
    else
      v_csv_array_associative[macd_histogram_max_${f_position}]=$f_macd_histogram_max
    fi
  fi
  
  # calculate relative trend strength (percentage 100 = strongest in history)
  g_percentage-diff ${f_macd_histogram_max} ${f_macd_histogram_positive}
  [[ -z "$g_percentage_diff_result" ]]  && g_percentage_diff_result=0
  g_calc "100+(${g_percentage_diff_result})"
  f_macd_histogram_strength=${g_calc_result}
  v_csv_array_associative[macd_histogram_strength_${f_position}]=$f_macd_histogram_strength
  
}
