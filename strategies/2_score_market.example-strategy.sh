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

## Check the classic market
timeframe=1d
above ema12 ema100 1 ECONOMY_SP500
above ema12 ema100 1 ECONOMY_NASDAQ
above ema50 ema200 1 ECONOMY_SP500
above ema50 ema200 1 ECONOMY_NASDAQ
above close_5m close 1 ECONOMY_NASDAQ
above close_5m close 1 ECONOMY_SP500
above ema100 ema12 1 ECONOMY_DXY
above ema200 ema50 1 ECONOMY_DXY
above close close_5m 1 ECONOMY_DXY

# check lead currencies for breakout (forced uptrend for the whole market)
for lead_currency in BTC ETH
do
  g_percentage-diff ${v[${lead_currency}USDT_1d_close_0]} ${v[${lead_currency}USDT_price]}
  g_num_is_higher $g_percentage_diff_result 5 && score 2 "${lead_currency} week breakout"
  g_num_is_higher $g_percentage_diff_result 10 && score 4 "${lead_currency} extreme week breakout"

  g_percentage-diff ${v[${lead_currency}USDT_1d_close_0]} ${v[${lead_currency}USDT_price]}
  g_num_is_higher $g_percentage_diff_result 3 && score 2 "${lead_currency} day breakout"
  g_num_is_higher $g_percentage_diff_result 10 && score 4 "${lead_currency} extreme week breakout"
done

# check m2 money supply
g_num_is_higher "${v[m2_3_month_delay]}" 0.5 && score 2 "US M2 money supply rising >0.5"

# check fear and grees


# save as market_score
market_score=$s_score
market_score_hist=$s_score_hist

