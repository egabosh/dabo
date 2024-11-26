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


function get_vars_from_csv {

  unset f_empty_var
  f_ASSET_HIST_FILE="$1"
  if ! [ -s "${f_ASSET_HIST_FILE}" ]
  then
    g_echo_warn "${f_ASSET_HIST_FILE} does not exist or is empty"
    return 1
  fi

  if [ -z "${f_market_performance}" ]
  then
    f_market_performance="0"
  fi
  f_all_vars="f_market_performance=${f_market_performance}"

  # read last 4 lines in array if not given
  unset f_last_lines_array
  if [ -z "${f_last_lines_array}" ]
  then
    mapfile -t f_last_lines_array < <(tail -n4 "${f_ASSET_HIST_FILE}")
  fi

  # if there are not four lines
  if [ -z "${f_last_lines_array[3]}" ]
  then
    return 1
  fi

  # create array of last line fields
  f_last_line="${f_last_lines_array[$((${#f_last_lines_array[@]}-1))]},${f_market_performance}"
  readarray -d "," -t f_last_line_array < <(echo "0,${f_last_line}")
  readarray -d "," -t f_2_last_line_array < <(echo "0,${f_last_lines_array[$((${#f_last_lines_array[@]}-2))]}")
  readarray -d "," -t f_3_last_line_array < <(echo "0,${f_last_lines_array[$((${#f_last_lines_array[@]}-3))]}")
  readarray -d "," -t f_4_last_line_array < <(echo "0,${f_last_lines_array[$((${#f_last_lines_array[@]}-4))]}")

  # bash-only basename
  f_asset="${f_ASSET_HIST_FILE##*/}"
  
  # basics
  get_var_from_line date 1
  get_var_from_line price 2

  # get newest price from raw file if this is a non-full loop
  if [ ${FULL_LOOP} == 0 ] 
  then
    readarray -d "," -t f_last_line_raw_array < <(tail -n1 "${f_ASSET_HIST_FILE/.csv/-raw.csv}")
    f_price=${f_last_line_raw_array[1]}
  fi

  get_var_from_line price_change 3
 
  # Check for price trend last 4 iterations
  g_percentage-diff ${f_4_last_line_array[2]} ${f_price}
  f_last_4_prices_change=${g_percentage_diff_result}
  
  if g_num_is_higher ${f_last_4_prices_change} 0
  then 
    f_price_trend="growing,${f_last_4_prices_change}"
    if g_num_is_higher ${f_3_last_line_array[2]} ${f_4_last_line_array[2]} && g_num_is_higher ${f_2_last_line_array[2]} ${f_3_last_line_array[2]} && g_num_is_higher ${f_price} ${f_2_last_line_array[2]}
    then
      f_price_trend="constantly growing,${f_last_4_prices_change}"
    fi
  elif g_num_is_lower ${f_last_4_prices_change} 0
  then
    f_price_trend="falling,${f_last_4_prices_change}"
    if g_num_is_lower ${f_3_last_line_array[2]} ${f_4_last_line_array[2]} && g_num_is_lower ${f_2_last_line_array[2]} ${f_3_last_line_array[2]} && g_num_is_lower ${f_price} ${f_2_last_line_array[2]}
    then
      f_price_trend="constantly falling,${f_last_4_prices_change}"
    fi
  else
    f_price_trend="constant,${f_last_4_prices_change}"
  fi
  f_all_vars="$f_all_vars
f_price_trend=${f_price_trend}"

  # MACD EMA
  get_var_from_line ema12 4
  get_var_from_line ema26 5

  # MACD
  get_var_from_line macd_histogram 8
  get_var_from_line macd_signal_relation 9
  f_macd_histogram_relation="${f_macd_signal_relation%|*}"
  [ -z "$f_macd_histogram_relation" ] && return 1
  f_macd_histogram_signal="${f_macd_signal_relation#*|}"
  f_all_vars="${f_all_vars}
f_macd_histogram_relation=${f_macd_histogram_relation}
f_macd_histogram_signal=${f_macd_histogram_signal}"

  # rsi
  get_var_from_line rsi5 10
  get_var_from_line rsi14 11
  get_var_from_line rsi21 12
  get_var_from_line rsi720 13
  get_var_from_line rsi60 14
  get_var_from_line rsi120 15
  get_var_from_line rsi240 16
  get_var_from_line rsi420 17
  
  # price changes
  get_var_from_line price_change_1_day 18
  get_var_from_line price_change_7_day 19
  get_var_from_line price_change_14_day 20
  get_var_from_line price_change_30_day 21
  get_var_from_line price_change_1_year 22

  # marketcap
  get_var_from_line marketcap_change_1_day 23

  # range and fibonacci
  get_var_from_line range_date 24
  get_var_from_line lowest_in_range 25
  get_var_from_line highest_in_range 26
  get_var_from_line pivot_point 27
  get_var_from_line support1 28
  get_var_from_line resist1 29
  get_var_from_line golden_pocket_support 30
  get_var_from_line golden_pocket_resist 31
  get_var_from_line golden_pocket65_support 32
  get_var_from_line golden_pocket65_resist 33
  get_var_from_line support3 34
  get_var_from_line resist3 35
  
  # EMAs
  get_var_from_line ema50 36
  get_var_from_line ema100 37
  get_var_from_line ema200 38
  get_var_from_line ema800 39

  # Coingecko price
  get_var_from_line coingecko_price 40

  if [ -n "${f_empty_var}" ]
  then
    return 1
  fi

}

function get_var_from_line {
  if [ -z "${f_last_line_array[$2]}" ]  
  then 
    declare -g f_$1=0
    if ! [[ "$1" =~ ^ema800$ ]]
    then
      g_echo_note "${f_ASSET_HIST_FILE}: Didn't get $1 in position $2"
      f_empty_var=1
    fi
  else
    # next line for exponential numbers (e.g. 7.86890874600464e05) to "normal" - coming sometimes from coingecko
    [[ ${f_last_line_array[$2]} =~ ^(-)?(\.)?[0-9]+(\.)?([0-9]+)?(e-[0-9]+)?$ ]] && printf -v f_last_line_array[$2] -- "%.10f" "${f_last_line_array[$2]}"
    declare -g f_$1="${f_last_line_array[$2]}"
  fi
  f_all_vars="$f_all_vars
f_$1=$(echo ${f_last_line_array[$2]})"
}

