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


function get_marketdata_yahoo {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
  local f_item="$1"
  local f_name="$2"
  local f_timeframe="$3"

  #local f_targetcsv="asset-histories/${f_name}.history-yahoo.csv"
  local f_targetcsvtmp="${g_tmp}/${f_name}.history-yahoo.csv"
  local f_targetjsontmp="${g_tmp}/${f_name}.history-yahoo.json"
  rm -f "$f_targetcsvtmp" "$f_targetjsontmp"

  [ -z "$f_timeframe" ] && f_timeframe="1d"
  local f_targetcsv="asset-histories/${f_name}.history-yahoo.${f_timeframe}.csv"
  local f_targetbotcsv="asset-histories/${f_name}.history.${f_timeframe}.csv"
  [ "$f_timeframe" = "1w" ] && f_timeframe="1wk"
  f_histfile_yahoo="$f_targetcsv"

  # transform CCXT symbols to Yahoo symbol
  if [[ $f_item =~ / ]]
  then
    # change / to -
    f_item=${f_item////-}
    # remove :* (:USDT in contract markets)
    f_item=${f_item//:*}
    # remove spaces
    f_item=${f_item/ /}
  fi

  # USDT to USD
  f_item=${f_item//USDT/USD}
  # BUSD to USD
  f_item=${f_item//BUSD/USD}

  # special names of some economy data/indexes of yahoo finance
  [[ $f_item = "DXY" ]] && f_item="DX=F"
  [[ $f_item = "DOWJONES" ]] && f_item="YM=F"
  [[ $f_item = "SP500" ]] && f_item="ES=F"
  [[ $f_item = "NASDAQ" ]] && f_item="NQ=F"
  [[ $f_item = "MSCIEAFE" ]] && f_item="MFS=F"
  [[ $f_item = "MSCIWORLD" ]] && f_item="IWDA.AS"
  [[ $f_item = "10YRTREASURY" ]] && f_item="ZB=F"
  [[ $f_item = "OIL" ]] && f_item="MCL=F"
  [[ $f_item = "GOLD" ]] && f_item="GC=F"
  [[ $f_item = "OILGAS" ]] && f_item="IEO"
  [[ $f_item = "USD-EUR" ]] && f_item="USDEUR=X"
  [[ $f_item = "EUR-USD" ]] && f_item="EURUSD=X"

  # end if already failed the last 5 minutes
  if [ -f "FAILED_YAHOO/${f_name}_HISTORIC_DOWNLOAD" ]
  then
    find "FAILED_YAHOO/${f_name}_HISTORIC_DOWNLOAD" -mmin +5 -delete
    if [ -f "FAILED_YAHOO/${f_name}_HISTORIC_DOWNLOAD" ]
    then
      return 1
    fi
  fi

  # end if already exists and modified under given time
  if [ -s "${f_targetcsv}" ] && find "${f_targetcsv}" -mmin -2 | grep -q "${f_targetcsv}"
  then
    return 0
  fi

  local f_sec
  printf -v f_sec '%(%s)T'
  # cleanup
  rm -f "$f_targetcsvtmp" "${f_targetcsvtmp}".err ${f_targetjsontmp} "${f_targetjsontmp}".err

  local f_from
  [ "$f_timeframe" = "5m" ] && f_from=$(date -d "now -86000 minutes" +%s)
  [ "$f_timeframe" = "15m" ] && f_from=$(date -d "now -86000 minutes" +%s)
  [ "$f_timeframe" = "1h" ] && f_from=$(date -d "now -17510 hour" +%s)
  [ "$f_timeframe" = "1d" ] && f_from=1
  [ "$f_timeframe" = "1wk" ] && f_from=1
  [ "$f_timeframe" = "1mo" ] && f_from=1

  # Download data from yahoo
  g_wget -O "${f_targetjsontmp}" "https://query1.finance.yahoo.com/v8/finance/chart/${f_item}?interval=${f_timeframe}&period1=${f_from}&period2=${f_sec}" 2>"${f_targetjsontmp}".err

  # Create csv from json
  jq -r '.chart.result[0] as $result | range(0; $result.timestamp | length) | [$result.timestamp[.], $result.indicators.quote[0].open[.], $result.indicators.quote[0].high[.], $result.indicators.quote[0].low[.], $result.indicators.quote[0].close[.], $result.indicators.quote[0].volume[.]] | @csv' "${f_targetjsontmp}" >"${f_targetcsvtmp}.unixtime" 2>"${f_targetjsontmp}".err

  # remove last/open timeframe (use only closed)
  sed -i '$d' "${f_targetcsvtmp}.unixtime"

  # change unix time to human readable and fill unfilled lines, ignore lines not with 00 secolds (last line)
  local date_time open high low close lastopen lasthigh lastlow lastclose volume
  while IFS=, read -r timestamp open high low close volume
  do
    if [ "$f_timeframe" = "1d" ] || [ "$f_timeframe" = "1mo" ]
    then
      printf -v date_time "%(%Y-%m-%d)T" $timestamp
    elif [ "$f_timeframe" = "1wk" ]
    then
      # on week 1 day back like crypto assets
      date_time=$(date -d "yesterday $(date -d "@$timestamp" "+%Y-%m-%d")" "+%Y-%m-%d")
    else
      printf -v date_time "%(%Y-%m-%d %H:%M:%S)T" $timestamp
    fi
    [ -z "$open" ] && open=$lastopen
    [ -z "$high" ] && high=$lasthigh
    [ -z "$low" ] && low=$lastlow
    [ -z "$close" ] && close=$lastclose
    [ -z "$volume" ] && volume=0
    lastopen=$open 
    lasthigh=$high
    lastlow=$low
    lastclose=$close
    echo "$date_time,$open,$high,$low,$close,$volume"
  done < "${f_targetcsvtmp}.unixtime" >${f_targetcsvtmp}

  # error if no csvfile available
  if ! [ -s "${f_targetcsvtmp}" ]
  then
    mkdir -p FAILED_YAHOO
    cat "${f_targetcsvtmp}.err" "${f_targetjsontmp}.err" > "FAILED_YAHOO/${f_name}_HISTORIC_DOWNLOAD" 2>/dev/null
    f_get_marketdata_yahoo_error=$(cat "${f_targetcsvtmp}.err" "${f_targetjsontmp}.err" 2>/dev/null)
    return 1
  fi
  
  # put the csvs together
  # history-yahoo file
  if [ -s "${f_targetcsv}" ] && [ -s "${f_targetcsvtmp}" ]
  then
    egrep -h "^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-9][0-9].*,[0-9]" "${f_targetcsv}" "${f_targetcsvtmp}" | sort -k1,2 -t, -u | sort -k1,1 -t, -u >"${f_targetcsv}.tmp"
    mv "${f_targetcsv}.tmp" "${f_targetcsv}"
  else
    egrep -h "^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-9][0-9].*,[0-9]" "${f_targetcsvtmp}" | sort -k1,2 -t, -u >"$f_targetcsv"
  fi

  # bots history file
  if [ -s "${f_targetbotcsv}" ] && [ -s "${f_targetcsv}" ]
  then
    egrep -h "^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-9][0-9].*,[0-9]" "${f_targetbotcsv}" "${f_targetcsv}" | sort -k1,2 -t, -u | sort -k1,1 -t, -u >"${f_targetbotcsv}.tmp"
    mv "${f_targetbotcsv}.tmp" "${f_targetbotcsv}"
  else
    egrep -h "^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-9][0-9].*,[0-9]" "${f_targetcsv}" | sort -k1,2 -t, -u >"$f_targetbotcsv"
  fi


}
