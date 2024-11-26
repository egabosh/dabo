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


function check_buy_conditions {

  local f_ASSET_HIST_FILE="$1"
  f_ASSET=$(basename ${f_ASSET_HIST_FILE} | cut -d\. -f1)

  if ! [ "$2" == "SELL" ]
  then
    if [ -n "${BOT}" ]
    then
      # ignore already invested asset 
      if ls trade-histories/trade-*${f_ASSET}-open.history.csv >/dev/null 2>&1
      then
        g_echo_note "BUY ${f_ASSET}@${CURRENCY}: $f_ASSET Already invested - ignoring for more diversification"
        return 0
      fi
    fi
  fi
  
  # get asset vars
  if [ -n "${BOT}" ] 
  then 
    get_vars_from_csv "${f_ASSET_HIST_FILE}" || return 1
  fi
  
  ### from here: check for defined state to buy
  f_BUY=""

  # run strategies
  if [ -z "$f_buy_strategies_array" ] 
  then 
    local f_strategy_path=../../strategies
    [ -z "${BOT}" ] && f_strategy_path=strategies
    mapfile -t f_buy_strategies_array < <(find ${f_strategy_path} -name "buy.*.conf" -type f)
  fi
  #for f_strategy in $(find ${f_strategy_path} -name "buy.*.conf" -type f)
  for f_strategy in "${f_buy_strategies_array[@]}"
  do
    f_echo_prefix="BUY ${f_ASSET}@${CURRENCY}:${f_price}:${f_strategy} - "
    if check_buy_conditions_strategy ${f_ASSET_HIST_FILE} ${f_strategy} 
    then 
      f_BUY="${f_echo_prefix} All BUY conditions met!!!"
      break
    fi
  done

  # if this checks came from sell function
  #if [ "$2" == "SELL" ]
  #then
  #  [ -n "$f_BUY" ] && return 1
  #  return 0
  #fi

  ### Buy or not buy?
  # BOT
  if [ -n "$f_BUY" ] && [ -n "${BOT}" ]
  then
    echo "${f_last_line},${f_ASSET}" >>trade.log

    g_echo_note "${f_BUY}"

    # calculate quantity from balance for potentially invest
    g_calc "scale=2; ${CURRENCY_BALANCE}/100*${INVEST}"
    local f_INVEST_QUANTITY=$(echo "${g_calc_result}" | cut -d\. -f1)
    g_echo_note "BUY current investment quantity is ${f_INVEST_QUANTITY} ${CURRENCY}"

    # remove CURRENCY from asset
    f_ASSET=$(echo ${f_ASSET} | sed "s/${CURRENCY}//")

    order ${f_ASSET}/${CURRENCY} ${f_INVEST_QUANTITY} buy
    f_BUY=""
  fi

#  # ANALYZE
#  if [ -n "$f_BUY" ] && [ -z "${BOT}" ]
#  then
#    echo "BUY: ${f_BUY}"
##echo "${csv_headline},Marketperformance
##${f_last_line}" | cut -d, -f 2-22 | perl -pe 's/([0-9].[0-9][0-9][0-9][0-9][0-9][0-9])[0-9]+/$1/g' | perl -pe 's/((?<=,)|(?<=^)),/ ,/g;' | column -t -s,
#    f_open_trade=1
#    #echo "${f_echo_prefix}${f_BUY}" >${g_tmp}/open-${tmpfile}
#    BUY_PRICE=$f_price
#    f_BUY=""
#  fi



}


function check_buy_conditions_strategy {

  # load strategy
  local f_echo_prefix="BUY ${f_ASSET}@${CURRENCY}:${f_price}:${f_strategy} - "
  f_do_buy=""
  [ -n "${BOT}" ] && g_echo_note "${f_echo_prefix}Running BUY checks"

  #if [ -s "${f_strategy}" ]
  #then
    . "${f_strategy}" || return 1
  #else
  #  g_echo_note "${f_echo_prefix}Strategy file not found"
  #  return 1
  #fi

  # Check buy signal from strategy
  if [ -n "${f_do_buy}" ]
  then
    echo "    ${f_echo_prefix} Strategy buy signal: ${f_do_buy}"
    return 0
  fi
  return 1

}

