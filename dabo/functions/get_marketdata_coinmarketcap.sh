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


function get_marketdata_coinmarketcap {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
  local f_item="$1"
  local f_name="$2"
  local f_timeframe="$3"

  local f_targetcsvtmp="${g_tmp}/${f_name}.history-coinmarketcap.csv"
  local f_targetjsontmp="${g_tmp}/${f_name}.history-coinmarketcap.json"
  rm -f "$f_targetcsvtmp" "$f_targetjsontmp"

  [ -z "$f_timeframe" ] && f_timeframe="1d"
  local f_targetcsv="asset-histories/${f_name}.history-coinmarketcap.${f_timeframe}.csv"
  [ "$f_timeframe" = "1w" ] && f_timeframe="7d"
  f_histfile_coinmarketcap="$f_targetcsv"

  # use EUR EURC stable coin fo EUR
  f_item=${f_item//EUR-/EURC-}
  
  # renamed cryptos
  f_item=${f_item//RNDR-/RENDER-}

  # remove -
  f_item=${f_item//-//}
  
  # USDT to USD
  f_item=${f_item//USDT/USD}
  # BUSD to USD
  f_item=${f_item//BUSD/USD}


  if ! [[ $f_item =~ /USD ]]
  then
   g_echo_error "${FUNCNAME} $@: Only USD supported"
   return 1
  fi

  # transform CCXT symbols to CoinmarketCap IDs
  if [[ $f_item =~ / ]]
  then
    # remove /*
    f_item=${f_item///*/}
  fi

  local f_id
  # get id -> If multiple take the one with the largest marketcap
  f_id=$(egrep "^${f_item},[1-9]" COINMARKETCAPIDS COINMARKETCAPIDS.tmp 2>/dev/null | sort -n -t, -k4 | tail -n1 | cut -d, -f2)
  [[ $f_item = EURC ]] && f_id=20641
  if [ -z "$f_id" ]
  then
    g_echo_error "${FUNCNAME} $@: No CoinMarketCap ID for $f_item"
    return 1
  fi

  # end if already failed the last 5 minutes
  if [ -f "FAILED_COINMARKETCAP/${f_name}_HISTORIC_DOWNLOAD" ]
  then
    find "FAILED_COINMARKETCAP/${f_name}_HISTORIC_DOWNLOAD" -mmin +5 -delete
    if [ -f "FAILED_COINMARKETCAP/${f_name}_HISTORIC_DOWNLOAD" ]
    then
      return 1
    fi
  fi

  # end if already exists and modified under given time
  if [ -s "${f_targetcsv}" ] && find "${f_targetcsv}" -mmin -2 | grep -q "${f_targetcsv}"
  then
    return 0
  fi

  # cleanup
  rm -f "$f_targetcsvtmp" "${f_targetcsvtmp}".err ${f_targetjsontmp} "${f_targetjsontmp}".err

  if [ "$f_timeframe" = "1d" ] || [ "$f_timeframe" = "7d" ]
  then
    # Download data from coinmarketcap
    g_wget -O "${f_targetjsontmp}" "https://api.coinmarketcap.com/data-api/v3.1/cryptocurrency/historical?id=${f_id}&interval=${f_timeframe}" 2>"${f_targetjsontmp}".err
    jq -r '.data.quotes[] | .quote.timestamp[0:10] + "," + (.quote.open|tostring) + "," + (.quote.high|tostring) + "," + (.quote.low|tostring) + "," + (.quote.close|tostring) + "," + (.quote.volume|tostring)' "${f_targetjsontmp}" | egrep -v ',0$|,$' >"${f_targetcsvtmp}" 2>"${f_targetjsontmp}".err
  else
    g_echo_error "${FUNCNAME} $@: Timeframe $f_timeframe in CoinMarketCap not supported."
    return 1
  fi

  # error if no csvfile available
  if ! [ -s "${f_targetcsvtmp}" ]
  then
    mkdir -p FAILED_COINMARKETCAP
    cat "${f_targetcsvtmp}.err" "${f_targetjsontmp}.err" > "FAILED_COINMARKETCAP/${f_name}_HISTORIC_DOWNLOAD" 2>/dev/null
    f_get_marketdata_coinmarketcap_error=$(cat "${f_targetcsvtmp}.err" "${f_targetjsontmp}.err" 2>/dev/null)
    return 1
  fi
  
  # put the csvs together
  if [ -s "${f_targetcsv}" ] && [ -s "${f_targetcsvtmp}" ]
  then
    egrep -h "^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-9][0-9].*,[0-9]" "${f_targetcsv}" "${f_targetcsvtmp}" | sort -k1,2 -t, -u | sort -k1,1 -t, -u >"${f_targetcsv}.tmp"
    mv "${f_targetcsv}.tmp" "${f_targetcsv}"
  else
    egrep -h "^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-9][0-9].*,[0-9]" "${f_targetcsvtmp}" | sort -k1,2 -t, -u >"$f_targetcsv"
  fi
  
  # change exponential notation to normal notation
  g_num_exponential2normal_file "${f_targetcsv}"

}

function get_marketdata_coinmarketcap_ids {

  # get symbol ids from coinmarketcap

  local f_target=COINMARKETCAPIDS
  local f_target_tmp="${f_target}.tmp"
  local f_target_loop=$f_target_tmp
  local f_latest_date
  local f_latest_date_seconds
  local f_latest_date_seconds_now=$(date -d "now - 8 days" +%s)

  # write direct to target if not exists or empty
  [ -s "$f_target" ] || f_target_loop=$f_target

  for f_id in $(seq 1 50000)
  do
    #echo "checking COINMARKETCAPID $f_id - Writing to $f_target_loop" 1>&2
   
    sleep 0.3
    # download
    curl -s --request GET  --url "https://api.coinmarketcap.com/data-api/v3.1/cryptocurrency/historical?id=${f_id}&interval=1d" >"$g_tmp/get_marketdata_coinmarketcap_ids.json"

    # check latest date
    f_latest_date=$(jq -r '.data.quotes[] | .quote.timestamp[0:10]' "$g_tmp/get_marketdata_coinmarketcap_ids.json" | tail -n1)
    [ -z "$f_latest_date" ] && continue

    # check for up-to-date data
    f_latest_date_seconds=$(date -d "$f_latest_date" +%s)
    if [ $f_latest_date_seconds_now -lt $f_latest_date_seconds ]
    then
      jq -r '.data | .symbol + "," + (.id|tostring) + "," + .name + "," + (.quotes[].quote|.marketCap|tostring)' "$g_tmp/get_marketdata_coinmarketcap_ids.json"  | grep -vi ",0e-" | head -n 1
    fi
  done | egrep --line-buffered '^.+,[0-9]*,' >"$f_target_loop"
  
  if [ -s "$f_target_tmp" ] 
  then
    cp -p "$f_target" "${f_target}.$(date +%F)"
    mv "$f_target_tmp" "$f_target"
  fi
}

