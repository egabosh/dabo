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


function calc_rsi {
  
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  # - needs array ${v_csv_array_associative[${f_column}_${i}] for example from g_read_csv
  # - needs $i as position
 
  local f_period=$1  # integer!
  local f_column=$2  # column in "$v_csv_array_associative" from which rsi should be calculated
  local f_target_column=$3  # column with previus RSIs - if not given "rsi$f_period" is used

  local f_position=$i  # position

  # check if there is a position (i from loop through array)
  [[ -z "$f_position" ]]  && return 1

  # check if there is a period if not default to 14
  [[ -z "$f_period" ]]  && f_period=14

  # check if there is a column (i from loop through array)
  [[ -z "$f_column" ]]  && return 3

  # check for enough positions/values to calculate (enough values)
  [[ $f_position -ge $f_period ]]  || return 0

  # get rsi column
  [[ -z "$f_target_column" ]]  && f_target_column="rsi$f_period"

  local f_last_value=${v_csv_array_associative[${f_column}_${f_position}]}
  [[ -z "$f_target_column" ]]  && return 4

  local v

  # reset old rsi sar
  unset f_rsi

  # get last $f_period values
  local f_last_period_values_from=$((f_position-$f_period+1))
  local f_last_period_values_positive=0
  local f_last_period_values_negative=0
  local f_last_period_num_positive=0
  local f_last_period_num_negative=0
  for ((v=$f_last_period_values_from; v<=${f_position}; v++))
  do
    if [[ ${v_csv_array_associative[${f_column}_${v}]} =~ ^- ]]
    then
      ((f_last_period_num_negative++))
      f_last_period_values_negative="$f_last_period_values_negative+(${v_csv_array_associative[${f_column}_${v}]})"
    else
      ((f_last_period_num_positive++))
      f_last_period_values_positive="$f_last_period_values_positive+${v_csv_array_associative[${f_column}_${v}]}"
    fi
  done

  # add positive and negative values
  g_calc "$f_last_period_values_positive"
  local f_positive_sum=$g_calc_result
  g_calc "$f_last_period_values_negative"
  local f_negative_sum=${g_calc_result//-}  

  # if one of both is "0" then fix results
  [[ ${f_negative_sum} = "0" ]]  && f_rsi=100
  [[ ${f_positive_sum} = "0" ]]  && f_rsi=1
  
  # calculate RSI
  if [[ -z "$f_rsi" ]] 
  then
    # calculate positive/negative change averages
    g_calc "${f_negative_sum}/${f_last_period_num_negative}"
    local f_negative_sum_average=$g_calc_result
    g_calc "${f_positive_sum}/${f_last_period_num_positive}"
    local f_positive_sum_average=$g_calc_result

    # calculate RS
    g_calc "${f_positive_sum_average}/${f_negative_sum_average}"
    local f_rs=$g_calc_result

    # calculate RSI
    g_calc "100-(100/(1+${f_rs}))"
    printf -v f_rsi "%.0f" $g_calc_result
  fi

  v_csv_array_associative[${f_target_column}_${f_position}]=$f_rsi

}

