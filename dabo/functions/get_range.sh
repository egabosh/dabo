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



function get_range {

  #g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  # get histfile
  local f_hist_file="$1"
   
  # Get last days (past day is the usual range for calculationg Levels / Pivot Point) - Should be Tiomezone where most traders on exchange are in
  local f_latest_date=$(tail -n1 ${f_hist_file} | cut -d, -f1)
  local f_range_yesterday=$(date "+%F" --date="${f_latest_date} 2-days-ago")
  local f_range_day=$(date "+%F" --date="${f_latest_date} 3-days-ago")
  # winter time
  if date +%Z | grep -q "CET"
  then
    local f_range_data=$(egrep "^${f_range_day} [0-2][1-9]:|^${f_range_day} 10:|^${f_range_day} 20:|^${f_range_yesterday} 00:" ${f_hist_file} | cut -d, -f2 | grep "^[0-9]")
  # summer time
  elif date +%Z | grep -q "CEST"
  then
    local f_range_data=$(egrep "^${f_range_day} [0-2][2-9]:|^${f_range_day} 1[0-1]:|^${f_range_day} 2[0-1]:|^${f_range_today} 0[0-1]:" ${f_hist_file} | cut -d, -f2 | grep "^[0-9]")
  # TODO: other - timezones!?
  else
    local f_range_data=$(grep "^${f_range_day} " ${f_hist_file} | cut -d, -f2 | grep "^[0-9]")
  fi

  # Check for new range
  local f_last_range_day=$(tail -n2 ${f_hist_file} | head -n1 | cut -d, -f24)
  if [[ -n "${f_last_range_day}" ]] 
  then
    if echo "${f_range_day}" | grep -q "${f_last_range_day}"
    then
      #g_echo_note "${FUNCNAME} $@: No new range"
      return 1
    fi
  fi
  
  if [[ -n "${f_range_data}" ]] 
  then
    local f_orig_ifs=${IFS}
    IFS=\n
    # get highest, lowest and closing price in range
    local f_highest_in_range=$(echo ${f_range_data} | sort -n | tail -n1)
    local f_lowest_in_range=$(echo ${f_range_data} | sort -n | head -n1)
    local f_closing_price_in_range=$(echo ${f_range_data} | tail -n1)
    IFS=${f_orig_ifs}
  
    # calculate Pivot Point (PP)
    local f_pivot_point=$(echo "scale=8; (${f_highest_in_range}+${f_lowest_in_range}+${f_closing_price_in_range})/3" | bc | sed 's/^\./0./;')
  
    # calculate support/resist and golden pocket
    local f_support1=$(echo "scale=8; ${f_pivot_point}-((${f_highest_in_range}-${f_lowest_in_range})*0.382)" | bc | sed 's/^\./0./;' )
    local f_resist1=$(echo "scale=8; ${f_pivot_point}+((${f_highest_in_range}-${f_lowest_in_range})*0.382)" | bc | sed 's/^\./0./;' )
    local f_golden_pocket_support=$(echo "scale=8; ${f_pivot_point}-((${f_highest_in_range}-${f_lowest_in_range})*0.618)" | bc | sed 's/^\./0./;' )
    local f_golden_pocket_resist=$(echo "scale=8; ${f_pivot_point}+((${f_highest_in_range}-${f_lowest_in_range})*0.618)" | bc | sed 's/^\./0./;' )
    local f_golden_pocket65_support=$(echo "scale=8; ${f_pivot_point}-((${f_highest_in_range}-${f_lowest_in_range})*0.65)" | bc | sed 's/^\./0./;' )
    local f_golden_pocket65_resist=$(echo "scale=8; ${f_pivot_point}+((${f_highest_in_range}-${f_lowest_in_range})*0.65)" | bc | sed 's/^\./0./;' )
    local f_support3=$(echo "scale=8; ${f_pivot_point}-((${f_highest_in_range}-${f_lowest_in_range})*1)" | bc | sed 's/^\./0./;' )
    local f_resist3=$(echo "scale=8; ${f_pivot_point}+((${f_highest_in_range}-${f_lowest_in_range})*1)" | bc | sed 's/^\./0./;' )
  else
    g_echo_note "${FUNCNAME} $@: Not enough data for calculating range"
    return 1
  fi 
  
   # write down in history 
  echo -n ",${f_range_day},${f_lowest_in_range},${f_highest_in_range},${f_pivot_point},${f_support1},${f_resist1},${f_golden_pocket_support},${f_golden_pocket_resist},${f_golden_pocket65_support},${f_golden_pocket65_resist},${f_support3},${f_resist3}" >>"${f_hist_file}"
  return 0

}

