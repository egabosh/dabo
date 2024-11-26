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


function check_sell_conditions {
  
  local f_ASSET_HIST_FILE="$1"
  f_ASSET=$(basename ${f_ASSET_HIST_FILE} | cut -d\. -f1)
 
  ### from here: check for defined state to sell
  f_SELL=""
 
  # get data
  if [ -n "${BOT}" ]
  then
    get_vars_from_csv ${f_ASSET_HIST_FILE} || return 1
  fi

  f_echo_prefix="SELL ${f_ASSET}@${CURRENCY}:${f_price} - "

  ### check current result

  # bot
  if [ -n "${BOT}" ] 
  then
    f_TRADE_HIST_FILE="$(ls -1tr trade-histories/trade-*${f_ASSET}-open.history.csv | tail -n1)"
    if ! [ -s "${f_TRADE_HIST_FILE}" ]
    then
      g_echo_note "${f_echo_prefix}No trade history file (${f_TRADE_HIST_FILE}) found - ignoring"
      return 0
    fi
    f_TRADE_HIST_FILE_INTERIM=$(echo ${f_TRADE_HIST_FILE} | sed 's/-open\.history\.csv$/-interim.history.csv/')
    f_BUY_PRICE=$(grep -i ',BUY,' $f_TRADE_HIST_FILE | tail -n1 | cut -d, -f5)
  else
    # analyze
    f_BUY_PRICE=${BUY_PRICE}
    f_TRADE_HIST_FILE="${g_tmp}/open-${tmpfile}"
    f_TRADE_HIST_FILE_INTERIM="${g_tmp}/interim-${tmpfile}"
  fi 

  # result values (sould be reduced to one - f_result!?)
  g_percentage-diff ${f_BUY_PRICE} ${f_price}
  f_result=${g_percentage_diff_result}
  f_BUY_PRICE_LAST_RATE_DIFF=${f_result}
  result=${f_result}
  g_calc "${f_result}-${FEE}"
  f_real_result=${g_calc_result}

  # analyze
  #[ -z "${BOT}" ] && echo "INTERIM RESULT: ${f_real_result}%"
    

  # store new interim result
  echo ${f_result} >>${f_TRADE_HIST_FILE_INTERIM} 

  # run strategies
#  f_strategy_path=../../strategies
#  [ -z "${BOT}" ] && f_strategy_path=strategies
  if [ -z "$f_sell_strategies_array" ] 
  then 
    local f_strategy_path=../../strategies
    [ -z "${BOT}" ] && f_strategy_path=strategies
    mapfile -t f_sell_strategies_array < <(find ${f_strategy_path} -name "sell.*.conf" -type f)
  fi
#  for f_strategy in $(find ${f_strategy_path} -name "sell.*.conf" -type f)
  for f_strategy in "${f_sell_strategies_array[@]}"
  do
    f_echo_prefix="SELL ${f_ASSET}@${CURRENCY}:${f_price}:${f_strategy} - "
    check_sell_conditions_strategy ${f_ASSET_HIST_FILE} ${f_strategy} ${f_TRADE_HIST_FILE} ${f_TRADE_HIST_FILE_INTERIM} ${f_BUY_PRICE} ${f_BUY_PRICE_LAST_RATE_DIFF}
    if [ -n "$f_SELL" ]
    then
      f_SELL="${f_echo_prefix}${f_SELL}" 
      break
    fi
  done

  #if [ -n "$f_SELL" ]
  #then
  #  # Check for filled buy conditions - if filled don't sell
  #  echo "    ${f_echo_prefix}Checking for filled buy conditions"  
  #  if ! check_buy_conditions ${f_ASSET_HIST_FILE} SELL
  #  then
  #    echo "  ${f_echo_prefix}Buy-Conditions met - dont sell"
  #    return 0
  #  fi
  #fi

  
  ### Sell or not sell?
  # BOT
  if [ -n "$f_SELL" ] && [ -n "${BOT}" ]
  then
    g_echo_note "$f_SELL"
    echo "${f_last_line},${f_ASSET}" >>trade.log
    f_ASSET=$(echo ${f_ASSET} | sed "s/${CURRENCY}//")
    position_close ${f_ASSET}/${CURRENCY}    
  fi

#  # ANALYZE
#  if [ -n "${f_SELL}" ] && [ -z "${BOT}" ]
#  then
#    echo "SELL: ${f_date} ${f_SELL}"
#    g_percentage-diff ${BUY_PRICE} ${f_price}
#    g_calc "${g_percentage_diff_result}-${FEE}"
#    result=${g_calc_result}
#    echo "${result}" >>${g_tmp}/result-${tmpfile}
#    rm -f "${f_TRADE_HIST_FILE}"
#    rm -f "${f_TRADE_HIST_FILE_INTERIM}"
#    unset f_open_trade
#    echo "RESULT: ${result}% (${BUY_PRICE} -> ${f_price})"
#  fi
 

}


function check_sell_conditions_strategy {

  local f_ASSET_HIST_FILE="$1"
  local f_strategy="$2"
  local f_TRADE_HIST_FILE="$3"
  local f_TRADE_HIST_FILE_INTERIM="$4"
  local f_BUY_PRICE="$5"
  local f_BUY_PRICE_LAST_RATE_DIFF="$6"

  f_do_sell=""

  # get iteration of current trade
  f_trade_iterations=$(cat ${f_TRADE_HIST_FILE_INTERIM} | wc -l)

  [ -n "${BOT}" ] && g_echo_note "${f_echo_prefix}Running SELL checks"

  # run strategy
#  if [ -s "${f_strategy}" ]
#  then
#    [ -z "${BOT}" ] && local f_strategy_name=$(echo ${f_strategy} | cut -d. -f2)
#    [ -n "${BOT}" ] && local f_strategy_name=$(echo ${f_strategy} | cut -d. -f6)
#    #if grep -q "buy.${f_strategy_name}.conf" ${f_TRADE_HIST_FILE}
#    #then
       . "${f_strategy}" || return 0
#    #fi
#  else
#    g_echo_note "${f_echo_prefix}Strategy file not found"
#    return 1
#  fi
  
  # Check sell signal from strategy
  if [ -n "${f_do_sell}" ]
  then
    f_SELL="Strategy sell signal: ${f_do_sell}"
    return 0
  fi

}
