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

# Assumption: crypto/bitcoin follows the money supply M2 with a 3-month delay
function get_m2_indicator {
  
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  f_m2_histfile="asset-histories/MARKETDATA_US_FED_M2_NS_MONEY_SUPPLY.history.1M.csv"
  #f_m2_histfile="asset-histories/MARKETDATA_US_FED_M2_SL_MONEY_SUPPLY.history.1M.csv"

  # use close value
  f_field=5
  # use open value if day of month <= 15
  [[ $(date +%-d) -le 15 ]] && f_field=2

  f_m2_3M_ago=$(grep "^$(date -d "$(date +%Y-%m-01) -3 months" +%Y-%m-%d)," $f_m2_histfile | cut -d, -f$f_field)
  f_m2_latest=$(tail -n1 $f_m2_histfile | cut -d, -f5)

  g_percentage-diff $f_m2_3M_ago $f_m2_latest
  echo "$g_percentage_diff_result" >m2_3_month_delay

}

