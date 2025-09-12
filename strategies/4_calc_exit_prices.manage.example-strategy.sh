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

# Example strategy for managing open positions

##### WARNING! This strategy is only intended as an example and should not be used with real trades!!! Please develop your own strategy ######


unset exits
declare -Ag exits

for asset in ${ASSETS[@]}
do

  unset exits_long 
  unset exits_short
  declare -a exits_long
  declare -a exits_short

  # find long exit prices
  for f_item in \
   15m_range_fibonacci_up_1786 \
   15m_range_fibonacci_up_1618 \
   15m_range_fibonacci_up_0 \
   15m_range_fibonacci_up_786 \
   15m_range_fibonacci_up_618 \
   1h_liquidity_12h_upprice \
   1h_liquidity_1d_upprice \
   1h_liquidity_3d_upprice
  do
    if [[ -z "${v[${asset}_${f_item}]}" ]]
    then
      g_echo_note "No v[${asset}_${f_item}]} data!"
      continue
    fi
    g_num_is_approx ${v[${asset}_${f_item}]} ${v[${asset}_price]} 0.05 0.05 && continue
    g_num_is_higher ${v[${asset}_${f_item}]} ${v[${asset}_price]} && exits_long+=(${v[${asset}_${f_item}]})
  done
  exits[${asset}_long]=${exits_long[@]}

  # find short exit prices if contract trade
  [[ -n "$LEVERAGE" ]] && for f_item in \
    15m_range_fibonacci_down_1786 \
    15m_range_fibonacci_down_1618 \
    15m_range_fibonacci_down_0 \
    15m_range_fibonacci_down_786 \
    15m_range_fibonacci_down_618 \
    1h_liquidity_12h_downprice \
    1h_liquidity_1d_downprice \
    1h_liquidity_3d_downprice
  do
    if [[ -z "${v[${asset}_${f_item}]}" ]] 
    then
      g_echo_note "No v[${asset}_${f_item}]} data!"
      continue
    fi
    g_num_is_approx ${v[${asset}_${f_item}]} ${v[${asset}_price]} 0.05 0.05 && continue
    g_num_is_lower ${v[${asset}_${f_item}]} ${v[${asset}_price]} && exits_short+=(${v[${asset}_${f_item}]})
  done
  exits[${asset}_short]=${exits_short[@]}
  
  g_echo_note "Exits Short $asset - ${exits[${asset}_short]}"
  g_echo_note "Exits Long $asset - ${exits[${asset}_long]}"

done
