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



function get_fibonaccis_all {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_timeframe=$1
  local f_rangefile f_symbol f_symbol_in_array

  get_symbols_ticker
  for f_symbol in "${f_symbols_array_trade[@]}"
  do
    f_symbol=${f_symbol%%:*}
    f_symbol=${f_symbol//\/}

    # get current price to reduce the range, save cpu-power and time
    f_symbol_in_array=${f_symbol/ /}

    f_rangefile="asset-histories/${f_symbol}.history.$f_timeframe.csv.range.chart"
    if [[ -s "$f_rangefile" ]]
    then
      read f_range_low f_range_high <"$f_rangefile"
    else
      continue
    fi

    printf '%(%Y-%m-%d %H:%M:%S)T' >"${f_rangefile}.fibonaccis-calculating"
    g_echo_note "Estimating current fibonacclevels of range $f_range_low $f_range_high ($f_rangefile)"

    f_rangefile="asset-histories/${f_symbol}.history.$f_timeframe.csv.range"
    if get_fibonaccis $f_range_low $f_range_high >"$f_rangefile.fibonacci.new"
    then
      mv "$f_rangefile.fibonacci.new" "$f_rangefile.fibonacci.chart"
      (printf '%(%Y-%m-%d %H:%M:%S)T'; echo -n "," ; cat "$f_rangefile.fibonacci.chart" | sort | cut -d" " -f 2 | paste -sd,) >>"$f_rangefile.fibonacci"
      printf '%(%Y-%m-%d %H:%M:%S)T' >"${f_rangefile}.fibonaccis-calculated"
    fi
    rm -f "${f_rangefile}.fibonaccis-calculating"

  done

}



function get_fibonaccis {

  local f_range_low=$1
  local f_range_high=$2
  local f_i
  
  g_num_valid_number $f_range_low $f_range_high || return 1

  local f_fibonacci_levels="0.236 0.382 0.500 0.618 0.650 0.786 1.236 1.382 1.500 1.618 1.650 1.786 2 2.236 2.382 2.500 2.618 2.650 2.786 3 3.236 3.382 3.500 3.618 3.650 3.786 4 4.236 4.382 4.500 4.618 4.650 4.786 5" 
  
  declare -A -l f_fibonaccis
  f_fibonaccis[up_0]=$f_range_high
  f_fibonaccis[up_1]=$f_range_low
  f_fibonaccis[down_0]=$f_range_low
  f_fibonaccis[down_1]=$f_range_high

  for f_fibonacci_level in $f_fibonacci_levels
  do
    for f_fibonacci_trend in up down
    do
      g_calc "${f_fibonaccis[${f_fibonacci_trend}_1]} - ( (${f_fibonaccis[${f_fibonacci_trend}_1]} - ${f_fibonaccis[${f_fibonacci_trend}_0]}) * $f_fibonacci_level )"
      f_fibonacci_level_arr_name=${f_fibonacci_level//.}
      f_fibonacci_level_arr_name=${f_fibonacci_level_arr_name#0}
      f_fibonaccis[${f_fibonacci_trend}_${f_fibonacci_level_arr_name}]=$g_calc_result
    done
  done

  for f_i in "${!f_fibonaccis[@]}"
  do 
    echo "$f_i ${f_fibonaccis[$f_i]}"
  done

}
