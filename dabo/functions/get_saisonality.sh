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



# calculates median of current and next month historic data and the average ot the two medians

function get_saisonality_month {
  
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  # get months
  local f_current_month
  printf -v f_current_month '%(%m)T'
  local f_next_month=$(date -d "next month" "+%m")

  get_symbols_ticker
  local f_asset
  for f_asset in ${ASSETS[@]}\
   $f_eco_assets
  do
    
    echo "X asset-histories/${f_asset}.history.1d.csv"

    # check if there is enough data
    [[ -s "asset-histories/${f_asset}.history.1d.csv" && $(wc -l < "asset-histories/${f_asset}.history.1d.csv") -gt 730 ]] || continue
    
    echo "asset-histories/${f_asset}.history.1d.csv"

    g_median < <(grep "^....-${f_current_month}-" "asset-histories/${f_asset}.history.1d.csv" | cut -d, -f7)
    local f_median_current_month=$g_median_result
  
    g_median < <(grep "^....-${f_next_month}-" "asset-histories/${f_asset}.history.1d.csv" | cut -d, -f7)
    local f_median_next_month=$g_median_result
  
    # calc avarage of this and next month saisonality
    g_calc "$f_median_next_month + $f_median_current_month / 2"
 
    local f_timestamp
    TZ=UTC printf -v f_timestamp '%(%Y-%m-%d %H:%M:%S)T'
    echo "$f_timestamp,$f_median_current_month,$f_median_next_month,$g_calc_result" >>"asset-histories/${f_asset}.saisonality"

  done

}

