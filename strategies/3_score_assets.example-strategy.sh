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


unset asset_score
declare -Ag score

for asset in ${ASSETS[@]}
do

  # restore market score as base
  s_score=$market_score
  s_score_hist=$market_score_hist

  g_echo_note "Scoring $asset"

  timeframe=1d
  cross ema50 ema100 1 $asset
  above ema12 ema100 1 $asset
  above ema50 ema200 1 $asset
  above close_5m close 1 $asset

  
  if [ -n "${v[${asset}_5m_rsi14_0]}" ]
  then
    rsi14=${v[${asset}_5m_rsi14_0]}
    g_num_is_between $rsi14 80 100 && score -4 "$asset RSI14 $rsi14 80-100"
    g_num_is_between $rsi14 55 80  && score  4 "$asset RSI14 $rsi14 55-80"
    g_num_is_between $rsi14 15 45  && score  2 "$asset RSI14 $rsi14 15-45"
    g_num_is_between $rsi14 0  15  && score -4 "$asset RSI14 $rsi14 0-15"
  fi

  [[ ${v[${asset}_1h_liquidity_12h_side]} = upsideliquidity ]] && score 4 "$asset 12h upsideliquidity"
  [[ ${v[${asset}_1h_liquidity_12h_side]} = downsideliquidity ]] && score  -4 "$asset 12h downsideliquidity"
  
  [[ ${v[${asset}_1h_liquidity_1d_side]} = upsideliquidity ]] && score 4 "$asset 1d upsideliquidity"
  [[ ${v[${asset}_1h_liquidity_1d_side]} = downsideliquidity ]] && score  -4 "$asset 1d downsideliquidity"

  [[ ${v[${asset}_1h_liquidity_3d_side]} = upsideliquidity ]] && score 4 "$asset 3d upsideliquidity"
  [[ ${v[${asset}_1h_liquidity_3d_side]} = downsideliquidity ]] && score  -4 "$asset 3d downsideliquidity"

  score[${asset}]=$s_score
  score[${asset}_hist]=$s_score_hist
  
  echo "${score[${asset}_hist]}" 1>&2
  echo "SCORE: ${score[${asset}]}" 1>&2

done
