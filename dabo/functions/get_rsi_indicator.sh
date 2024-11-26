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


function get_rsi_indicator {
  #g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
  # get histfile
  local f_hist_file="$1"
  local f_last_minutes="$2"

  # calculate change of lastest f_last_minutes+1 prices for calculating rsi over the last f_last_minutes periods
  local f_price
  local f_last_price
  local f_positive_sum=0
  local f_negative_sum=0
  f_rsi=""

  local f_period=$((f_last_minutes+1))
  local f_period_sum=$(tail -n${f_period} "${f_hist_file}" | cut -d, -f2 | grep "^[0-9]" | wc -l)
  if ! [ ${f_period_sum} -ge ${f_period} ]
  then
    g_echo_note "${FUNCNAME} $@: Not enough data - waiting for more values and defaulting to 50. (${f_period} needed; ${f_period_sum} given)"
    echo -n ",50" >>"${f_hist_file}"
    return 0
  fi
  
  f_positive_sum=$(tail -n${f_period} "${f_hist_file}" | cut -d"," -f3 | grep "^[0-9]" | awk "{ SUM += \$1} END { printf(\"%10.10f\", SUM/${f_period}) }")
  f_negative_sum=$(tail -n${f_period} "${f_hist_file}" | cut -d"," -f3 | grep "^-[0-9]" | awk "{ SUM += \$1} END { printf(\"%10.10f\", SUM/${f_period}) }")


  # if one of both is "0" then fix results
  if [ ${f_negative_sum} == "0.0000000000" ] 
  then
    f_rsi=100
    #g_echo_note "RSI-Indicator RSI: ${f_rsi}%"
    echo -n ",${f_rsi}" >>"${f_hist_file}"
    return 0
  fi

  if [ ${f_positive_sum} == "0.0000000000" ] 
  then
    f_rsi=0
    #g_echo_note "RSI-Indicator RSI: ${f_rsi}%"
    echo -n ",${f_rsi}" >>"${f_hist_file}"
    return 0
  fi

  # calculate positive/negative change averages
  local f_negative_sum_average=$(echo "${f_negative_sum}/${f_last_minutes}" | bc -l | sed 's/-//') 
  local f_positive_sum_average=$(echo "${f_positive_sum}/${f_last_minutes}" | bc -l)

  # calculate RS and RSI
  local f_rs=$(echo "${f_positive_sum_average}/${f_negative_sum_average}" | bc -l)
  f_rsi=$(echo "100-(100/(1+${f_rs}))" | bc -l | xargs printf "%.0f")
  
  echo -n ",${f_rsi}" >>"${f_hist_file}"

  #g_echo_note "RSI-Indicator RSI: ${f_rsi}%"
  
}

