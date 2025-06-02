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


function get_coingecko_data {
  # get data from coingecko
  local f_gecko_currencies="usd eur"
  [[ -f COINGECKO_GET_ASSETS_CMD_OUT ]]  || touch -t 197001010000 COINGECKO_GET_ASSETS_CMD_OUT
  if find COINGECKO_GET_ASSETS_CMD_OUT -mmin +5 2>/dev/null | grep -q COINGECKO_GET_ASSETS_CMD_OUT
  then
    for f_gecko_currency in ${f_gecko_currencies}
    do
      echo "curl -s -X 'GET' \"https://api.coingecko.com/api/v3/coins/markets?vs_currency=${f_gecko_currency}&order=market_cap_desc&per_page=250&page=1&sparkline=false&price_change_percentage=1h,24h,7d,14d,30d,1y\" -H 'accept: application/json'" >COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD
      g_runcmd g_retrycmd sh COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD >COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD_OUT_TMP || return 1
      local f_test_query=$(jq -r ".[] |select(.symbol==\"btc\")|\"\\(.current_price)\"" COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD_OUT_TMP)
      if g_num_valid_number ${f_test_query} 
      then
        mv COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD_OUT_TMP COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD_OUT
        [[ ${f_gecko_currency} =~ ^usd ]] && cat COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD_OUT >COINGECKO_GET_ASSETS_CMD_OUT
      else
        find COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD_OUT -mmin +15 2>/dev/null | grep -q COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD_OUT && g_echo_warn "Coingecko data older then 15min: $(ls -l COINGECKO_GET_ASSETS_${f_gecko_currency}_CMD_OUT)"
        return 1
      fi
    done
  fi

  [[ ${FULL_LOOP} == 0 ]]  && return 0
  if [[ -s COINGECKO_GET_ASSETS_CMD_OUT ]]  && grep -q "market_cap_rank" COINGECKO_GET_ASSETS_CMD_OUT
  then

    # get marketcap sort
    jq -r '.[].symbol' COINGECKO_GET_ASSETS_CMD_OUT | tr [:lower:] [:upper:] | head -n $LARGEST_MARKETCAP >ASSET_MARKETCAP_OUT.tmp-sort
    if [[ -s ASSET_MARKETCAP_OUT.tmp-sort ]]  && egrep -q "^[A-Z0-9]+$" ASSET_MARKETCAP_OUT.tmp-sort
    then
      mv ASSET_MARKETCAP_OUT.tmp-sort SORTMARKETCAP
    else
      g_echo_warn "ASSET_MARKETCAP_OUT.tmp-sort has wrong Syntax. - Not updating ASSET_MARKETCAP_OUT.tmp-sort $(tail -n 10 ASSET_MARKETCAP_OUT.tmp-sort)"
      return 2
    fi

    # write down 24h pricechange
    cat COINGECKO_GET_ASSETS_CMD_OUT | jq -r '.[] | .symbol + "," + (.price_change_percentage_24h|tostring)' | tr [:lower:] [:upper:] >ASSET_PRICE_CHANGE_PERCENTAGE_24H

    # store coingecko symbolids for coingecko info URLs
    jq -r '.[] | .symbol + "," + .id' COINGECKO_GET_ASSETS_CMD_OUT >COINGECKO_IDS.tmp
    if [[ -s COINGECKO_IDS.tmp ]] 
    then
      mv COINGECKO_IDS.tmp COINGECKO_IDS
    else
      g_echo_warn "COINGECKO_IDS.tmp has wrong Syntax. - Not updating COINGECKO_IDS $(tail -n 10 COINGECKO_IDS.tmp)"
      return 2
    fi
  fi
}
