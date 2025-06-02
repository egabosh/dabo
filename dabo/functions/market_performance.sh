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


function market_performance {
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
  
  if find MARKET_PERFORMANCE.csv -mmin -${INTERVAL_MIN} 2>/dev/null | grep -q "MARKET_PERFORMANCE.csv"
  then
    g_echo_note "MARKET_PERFORMANCE.csv already downloaded in the last ${INTERVAL_MIN} minutes"
    return 0
  fi

  ## function for scoring limits set in config up or down by specific (market) facts
  # generates variable f_market_performance
  # forecast bitcoin (is quartered because uncertain)
  f_url="https://30rates.com/btc-to-usd-forecast-today-dollar-to-bitcoin"
  [[ -e btc-forecast ]] && find btc-forecast -mmin +60 -delete
  if ! [[ -s btc-forecast ]]
  then
    g_runcmd g_retrycmd curl -s "$f_url" >btc-forecast || return 1
  fi
  local f_forecast=$(cat btc-forecast | hxnormalize -x | hxselect 'table' | grep "<strong>" | grep -A1 "Price" -m1 | tail -n1 | cut -d'>' -f3 | cut -d'<' -f1)
  if ! echo "$f_forecast" | egrep -q '^[0-9]*\.[0-9]*$|^[0-9]*$' 
  then
    g_echo_warn "Didn't get correct forecast from $f_url"
    return 1
  fi
  local f_today=$(cat btc-forecast | hxnormalize -x | hxselect 'table' | egrep '<strong>' | head -n1 | cut -d'>' -f3 | cut -d'<' -f1)
  if ! echo "$f_today" | egrep -q '^[0-9]*\.[0-9]*$|^[0-9]*$'
  then
    g_echo_warn "Didn't get correct forecast from $f_url"
    return 1
  fi
  g_percentage-diff ${f_today} ${f_forecast}
  local f_btc_forecast=${g_percentage_diff_result}
  echo $f_btc_forecast | egrep -q '[0-9]\.[0-9]' || return 1
  g_echo_note "BTC forecast: $f_btc_forecast"
  f_btc_forecast=$(echo "scale=2; ${f_btc_forecast}/3" | bc -l | sed -r 's/^(-?)\./\10./')


  # forecast ethereum (is quartered because uncertain)
  local f_url="https://30rates.com/ethereum-price-prediction-tomorrow-week-month-eth-forecast"
  [[ -e eth-forecast ]] && find eth-forecast -mmin +60 -delete
  if ! [[ -s eth-forecast ]]
  then
    g_runcmd g_retrycmd curl -s "$f_url" >eth-forecast || return 1
  fi
  f_forecast=$(cat eth-forecast | hxnormalize -x | hxselect 'table' | grep "<strong>" | grep -A1 "Price" -m1 | tail -n1 | cut -d'>' -f3 | cut -d'<' -f1)
  if ! echo "$f_forecast" | egrep -q '^[0-9]*\.[0-9]*$|^[0-9]*$'
  then
    g_echo_warn "Didn't get correct forecast $f_forecast from $f_url"
    return 1
  fi
  f_today=$(cat eth-forecast | hxnormalize -x | hxselect 'table' | egrep '<strong>' | head -n1 | cut -d'>' -f3 | cut -d'<' -f1)
  if ! echo "$f_today" | egrep -q '^[0-9]*\.[0-9]*$|^[0-9]*$'
  then
    g_echo_warn "Didn't get correct forecast from $f_url"
    return 1
  fi
  g_percentage-diff ${f_today} ${f_forecast}
  local f_eth_forecast=${g_percentage_diff_result}
  echo $f_eth_forecast | egrep -q '[0-9]\.[0-9]' || return 1
  g_echo_note "ETH forecast: $f_eth_forecast"
  f_eth_forecast=$(echo "scale=2; ${f_eth_forecast}/3" | bc -l | sed -r 's/^(-?)\./\10./')

  # Calculate available market data week changes
  local f_index_performance_added=0
  local f_index_performance_csv=""
  local f_INDEX
  local f_indexlist=$(ls -1t asset-histories/*INDEX*history.csv | egrep -v 'US-UNEMPLOYMENT-INDEX|US-CONSUMER-PRICE-INDEX|US-FED-FEDERAL-FUNDS-RATE-INVERTED' | perl -pe 's#asset-histories/(.+)-INDEX.history.csv#$1#')
  for f_INDEX in $f_indexlist
  do
    # day average 1 week ago
    local f_from=$(grep "^$(date "+%Y-%m-%d" -d "last week") " asset-histories/${f_INDEX}-INDEX.history.csv | cut -d, -f2  | awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; }')
    # fallback this or last month
    #[[ -z "${f_from}" ]] && f_from=$(grep "^$(date "+%Y-%m-")" asset-histories/${f_INDEX}-INDEX.history.csv | cut -d, -f2  | awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; }')
    #[[ -z "${f_from}" ]] && f_from=$(grep "^$(date "+%Y-%m-" -d "last month")" asset-histories/${f_INDEX}-INDEX.history.csv | cut -d, -f2  | awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; }')
    # if no data
    [[ -z "${f_from}" ]] && f_from=0
    # middle of latest 10 values
    local f_to=$(tail -n 10 asset-histories/${f_INDEX}-INDEX.history.csv | cut -d, -f2 | awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; }')
    [[ -z "${f_to}" ]] && f_to=0
    if [[ ${f_to} == "0" ]] || [[ ${f_from} == "0" ]]
    then
      # default to -0.1 if no week data available
      local f_index_performance="-0.1"
    else
      # calculate performance
      g_percentage-diff ${f_from} ${f_to}
      local f_index_performance=${g_percentage_diff_result}
    fi
    # if growing is bad for krypto - invert
    if echo ${f_INDEX} | grep -q INVERTED
    then
      if echo "${f_index_performance}" | grep -q ^-
      then
        f_index_performance=$(echo ${f_index_performance} | sed 's/^-//')
      else
        f_index_performance="-${f_index_performance}"
      fi
    fi
    # finishing vars
    f_index_performance_added="$(echo "scale=2; ${f_index_performance_added}+${f_index_performance}" | bc -l | sed -r 's/^(-?)\./\10./')"
    f_index_performance_csv="${f_index_performance_csv},${f_index_performance}"
  done

  # calculate US-FED-FEDERAL-FUNDS-RATE-INVERTED
  for f_eco_data in US-FED-FEDERAL-FUNDS-RATE-INVERTED-INDEX
  do
    local f_index_performance=$(tail -n 1 asset-histories/${f_eco_data}.history.csv | cut -d, -f2)
    if echo ${f_eco_data} | grep -q INVERTED
    then
      if echo "${f_index_performance}" | grep -q ^-
      then
        f_index_performance=$(echo ${f_index_performance} | sed 's/^-//')
      else
        f_index_performance="-${f_index_performance}"
      fi
    fi
    f_index_performance_added="$(echo "scale=2; ${f_index_performance_added}+${f_index_performance}" | bc -l | sed -r 's/^(-?)\./\10./')"
    f_index_performance_csv="${f_index_performance_csv},${f_index_performance}"
  done


  # calculate forecast US Unemployment Rate and US Consumer Price Index (CPI)
  for f_eco_data in US-UNEMPLOYMENT-INDEX US-CONSUMER-PRICE-INDEX
  do
    local f_current=$(tail -n 1 asset-histories/${f_eco_data}.history.csv | cut -d, -f2)
    #local f_forecast=$(tail -n 1 asset-histories/${f_eco_data}.history.csv | cut -d, -f3)
    #f_index_performance="$(echo "scale=2; ${f_current}-${f_forecast}" | bc -l | sed -r 's/^(-?)\./\10./')"
    f_index_performance_added="$(echo "scale=2; ${f_index_performance_added}+${f_current}" | bc -l | sed -r 's/^(-?)\./\10./')"
    f_index_performance_csv="${f_index_performance_csv},${f_current}"
  done

  # price performance bitcoin
  local f_btc_performance=$(jq -r '.[] |select(.symbol=="btc")|(.price_change_percentage_7d_in_currency)' COINGECKO_GET_ASSETS_CMD_OUT)
   
  # price performance ethereum
  local f_eth_performance=$(jq -r '.[] |select(.symbol=="eth")|(.price_change_percentage_7d_in_currency)' COINGECKO_GET_ASSETS_CMD_OUT)

  # hourly price performance  over TOP 250 marketcap by coingecko
  local f_top250_marketcap_performance=$(jq -r ".[].price_change_percentage_1h_in_currency" COINGECKO_GET_ASSETS_CMD_OUT  | awk '{ SUM += $1} END { printf("%.2f", SUM/250) }')

  ## calculate market performance
  f_market_performance=$(echo "scale=2; (${f_btc_forecast} + ${f_eth_forecast} + ${f_index_performance_added} + ${f_btc_performance} + ${f_eth_performance} + ${f_top250_marketcap_performance})" | bc -l | sed -r 's/^(-?)\./\10./' | xargs printf "%.2f")
  local f_date=$(g_date_print)
  local f_indexlistcsv=$(echo "$f_indexlist" | perl -pe 's/\n/,/g; s/ +/,/g; s/,+/,/g')
  local f_market_csv_headline="date,market performance,btc,eth,btc forecast,eth forecast,top250,${f_indexlistcsv}US-FED-FEDERAL-FUNDS-RATE-INVERTED,US-UNEMPLOYMENT,US-CONSUMER-PRICE"
  if [[ -s MARKET_PERFORMANCE.csv ]] 
  then
    sed -i -e 1c"$f_market_csv_headline" MARKET_PERFORMANCE.csv
  else
    echo "$f_market_csv_headline" >MARKET_PERFORMANCE.csv
  fi
  echo "${f_date},${f_market_performance},${f_btc_performance},${f_eth_performance},${f_btc_forecast},${f_eth_forecast},${f_top250_marketcap_performance}${f_index_performance_csv}" >>MARKET_PERFORMANCE.csv
  echo -n "${f_market_performance}" >MARKET_PERFORMANCE_LATEST
}

