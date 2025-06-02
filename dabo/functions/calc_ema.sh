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


function calc_ema {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  # - needs array ${v_csv_array_associative[${f_column}_${i}] for example from g_read_csv
  # - needs $i as position

  local f_period=$1  # integer!
  local f_column=$2  # column in "$v_csv_array_associative" from which ema should be calculated
  local f_target_column=$3  # column with previus EMAs - if not given "ema$f_period" is used

  local f_position=$i  # position

  # check if there is a position (i from loop through array)
  [[ -z $f_position ]] && return 1

  # check if there is a period (i from loop through array)
  [[ -z $f_period ]] && return 2

  # check if there is a column (i from loop through array)
  [[ -z $f_column ]] && return 3
  
  # get ema column
  [[ -z $f_target_column ]] && local f_target_column="ema$f_period"

  local f_last_value=${v_csv_array_associative[${f_column}_${f_position}]}
  [[ -z $f_target_column ]] && return 4

  local f_v

  # reset old ema var
  unset f_ema

  # find last EMA
  local f_last_ema_position=$((f_position-1))
  local f_last_ema=${v_csv_array_associative[${f_target_column}_${f_last_ema_position}]}

  # check for enough positions/values to calculate (enough values) if SMA needed
  if [[ -z $f_last_ema ]]
  then
    [[ $f_position -ge $f_period ]] || return 5
  fi

  # check if last EMA is given
  if [[ -n $f_last_ema ]]
  then
    # calc EMA with previous EMA if given
    g_calc "scale=10; ${f_last_value}*(2/(${f_period}+1))+${f_last_ema}*(1-(2/(${f_period}+1)))"
  else
    ## calc SMA if previous EMA is not given (only needed on first EMA calc)
    # get last $f_period values
    g_echo_note "calc SMA - previous EMA is not given"
    local f_last_period_values_from=$((f_position-$f_period+1))
    local f_last_period_values
    for ((f_v=$f_last_period_values_from; f_v<=${f_position}; f_v++))
    do
      if [[ -z $f_last_period_values ]]
      then
        f_last_period_values=${v_csv_array_associative[${f_column}_${f_v}]}
      else
        g_calc "${f_last_period_values}+${v_csv_array_associative[${f_column}_${f_v}]}"
        f_last_period_values=$g_calc_result
      fi
    done
    # calc SMA (EMA=SMA in this special first case)
    g_calc "($f_last_period_values)/$f_period"
  fi

  # write back EMA
  if [[ $g_calc_result =~ ^- ]]
  then
    if ! [[ $f_period = 9 ]] 
    then
      g_echo_warn "${FUNCNAME} $@: EMA can not be negative ($g_calc_result)"
      return 1
    fi
  fi
  v_csv_array_associative[${f_target_column}_${f_position}]=$g_calc_result
  f_ema=$g_calc_result
  return 0
}

