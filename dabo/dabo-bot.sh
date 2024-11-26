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

. /dabo/dabo-prep.sh

### MAIN ###
g_echo_note "STARTING DABO BOT $0"

touch firstloop
export FULL_LOOP=1

# am I the bot (important for functions used by analyze.sh
echo $0 | grep -q "dabo-bot\.sh" && BOT=1

# cleanup trashlines in asset-histories (possibly generated by kill further of this progress)
#find asset-histories -name "*.csv" -type f | while read csv_file
#do
#  csv_timestamp=$(ls --time-style='+%Y%m%d%H%M' -l "${csv_file}" | cut -d" " -f6)
#  sed -i "/[0-9]$(date +%Y)-/d" "${csv_file}"
#  touch -t ${csv_timestamp} "${csv_file}"
#done


# run endless loop
while true
do
  # wait until next full minute in the beginning to be able to work with continue in this loop
  if [ -f firstloop ]
  then
    rm -f firstloop
  else
    LOOP_INTERVAL=30
    time_to_interval=$((${LOOP_INTERVAL} - $(date +%s) % ${LOOP_INTERVAL}))
    time_to_full_interval=$((${INTERVAL} - $(date +%s) % ${INTERVAL}))
    # Check for next general interval
    g_echo_note "NEXT LOOP in ${time_to_interval} seconds (Interval=${LOOP_INTERVAL}s)"
    g_echo_note "NEXT FULL LOOP in ${time_to_full_interval} seconds (Interval=${INTERVAL}s)"
    if [ ${time_to_full_interval} -le  ${time_to_interval} ]
    then
      FULL_LOOP=1
      g_echo_note "FULL INTERVAL"
      sleep ${time_to_full_interval}
    else
      FULL_LOOP=0
      g_echo_note "SHORT INTERVAL"
      sleep ${time_to_interval}
    fi
  fi
  
  # reload config
  g_tries_delay=$(shuf -i 5-15 -n 1)
  . ../../dabo-bot.conf
  . ../../dabo-bot.override.conf

  # Timestamp
  export f_timestamp=$(g_date_print)


####### TODO -> Funktionen überarbeiten ############
#
#  # get minute interval for find -mmin (used by get_marketdata market_performance
#  INTERVAL_MIN=$(echo "${INTERVAL}/60-1" | bc -l | sed -r 's/^(-?)\./\10./' | cut -d\. -f1)
#  [ -z "${INTERVAL_MIN}" ] && INTERVAL_MIN=1
#
#  ### get general market data
#  # Get coingecko data
#  get_coingecko_data
#
#  # Get current MarketData
#  get_marketdata
#
#  # Check the situation on the market
#  if ! market_performance
#  then
#    f_market_performance=$(cat MARKET_PERFORMANCE_LATEST)
#  fi
####### TODO -> Funktionen überarbeiten ENDE ###########


  ## watch some manual defined assets
  #watch_assets
  
  if [ "${STOCK_EXCHANGE}" = "NONE" ]
  then
    ## stop here if STOCK_EXCHANGE not present
    continue   
  fi

  # Get current symbols
  #[ ${FULL_LOOP} = 1 ] && get_symbols_ticker
 
  # Sell something?
  #check_for_sell

  # Get current balance
  [ ${FULL_LOOP} = 1 ] && get_balance || continue

  # Get current positions
  [ ${FULL_LOOP} = 1 ] && get_positions || continue

  # Get current orders
  [ ${FULL_LOOP} = 1 ] && get_orders || continue

  ## Run  strategies
  [ ${FULL_LOOP} = 1 ] && run_strategies

done

