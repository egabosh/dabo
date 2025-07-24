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


function cross {
  
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  # usage: 
  # cross field1[_timeframe1] field2[_timeframe2] score [asset] [global timeframe]
  # cross close[_5m] close[_1d] 2 [ECONOMY_SP500] [1h]
  
  ## Get and check values

  local f_name1=${1%%_*}  # if f_name1 crosses f_name2 from bottom to top then bullish
  local f_name2=${2%%_*}  # if f_name2 crosses f_name1 from bottom to top then baerish
  local f_timeframe1=${1#*_}
  local f_timeframe2=${2#*_}
  [[ $f_name1 = $f_timeframe1 ]] && unset f_timeframe1
  [[ $f_name2 = $f_timeframe2 ]] && unset f_timeframe2
  local f_score=$3
  [[ -n "$4" ]] && local asset=$4
  [[ -n "$5" ]] && local timeframe=$5
  [[ -z "$f_timeframe1" ]] && f_timeframe1=$timeframe
  [[ -z "$f_timeframe2" ]] && f_timeframe2=$timeframe

  if [[ -z "$asset" ]]
  then
    g_echo_warn "${FUNCNAME} $@ No asset given"
    return 1
  fi

  if [[ -z "$timeframe" ]]
  then
    g_echo_warn "${FUNCNAME} $@ No timeframe given"
    return 1
  fi

  
  if ! g_num_valid_number "$f_score"
  then
    g_echo_warn "${FUNCNAME} $@ No score given"
    return 2
  fi

  local f_value1=${v[${asset}_${f_timeframe1}_${f_name1}_0]}
  local f_value2=${v[${asset}_${f_timeframe2}_${f_name2}_0]}
  local f_value1_last=${v[${asset}_${f_timeframe1}_${f_name1}_1]}
  local f_value2_last=${v[${asset}_${f_timeframe2}_${f_name2}_1]}
  
  if ! g_num_valid_number "$f_value1" "$f_value2" "$f_value1_last" "$f_value2_last" 2>/dev/null
  then
     g_echo_warn "${FUNCNAME} $@ At least one value empty:
     \${v[${asset}_${f_timeframe1}_${f_name1}_0]} ($f_value1)
     \${v[${asset}_${f_timeframe2}_${f_name2}_0]} ($f_value2)
     \${v[${asset}_${f_timeframe1}_${f_name1}_1]} ($f_value1_last)
     \${v[${asset}_${f_timeframe2}_${f_name2}_1]} ($f_value2_last)"
     return 3
  fi

  
  ## check for cross
  if g_num_is_higher $f_value1 $f_value2 && g_num_is_lower $f_value1_last $f_value2_last
  then
    score +${f_score} "$asset: $f_name1 ($f_timeframe1) crosses $f_name2 ($f_timeframe2) from bottom to top - Score +${f_score}"
  elif g_num_is_lower $f_value1 $f_value2 && g_num_is_higher $f_value1_last $f_value2_last
  then
    score -${f_score} "$asset: $f_name2 ($f_timeframe2) crosses $f_name1 ($f_timeframe1) from bottom to top - Score -${f_score}"
  fi

}
