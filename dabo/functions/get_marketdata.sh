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

function get_marketdata_all {
  local f_interval=$1
  
  # daily garketdata jobs
  if [[ $f_interval = 1d ]]
  then
    # FEAR_AND_GREED_ALTERNATIVEME
    get_marketdata FEAR_AND_GREED_ALTERNATIVEME 'https://api.alternative.me/fng/?limit=0&format=json' '.data[] | (.timestamp | tonumber | strftime("%Y-%m-%d")) + "," + .value + ",,,,0"' "" 1d

    # FEAR_AND_GREED_CNN
    get_marketdata FEAR_AND_GREED_CNN 'https://production.dataviz.cnn.io/index/fearandgreed/graphdata' '.fear_and_greed_historical.data[] | (.x/1000 | strftime("%Y-%m-%d")) + "," + (.y|tostring) + ",,,,0"' "" 1d

    # monthly US consumer price index CPI data
    get_marketdata US_CONSUMER_PRICE_INDEX_CPI "https://api.bls.gov/publicAPI/v2/timeseries/data/CUUR0000SA0?startyear=$(date -d 'now -8 years' '+%Y')&endyear=$(date '+%Y')" '.Results.series[0].data[] | .year + "-" + (.period | gsub("M"; ""))  + "-01," + .value + ",,,,0"' "" 1d

    # monthly US unemployment rate
    get_marketdata US_UNEMPLOYMENT_RATE "https://api.bls.gov/publicAPI/v2/timeseries/data/LNU03000000?startyear=$(date -d 'now -8 years' '+%Y')&endyear=$(date '+%Y')" '.Results.series[0].data[] | .year + "-" + (.period | gsub("M"; ""))  + "-01," + .value + ",,,,0"' "" 1d
  
    # US FED funds rate
    get_marketdata US_FED_FUNDS_RATE 'https://fred.stlouisfed.org/graph/fredgraph.csv?id=DFF' "" "" 1d    

  fi

   # Binance Long Short Ration Account / Taker and Open Interest per symbol
   get_symbols_ticker
   local f_symbol f_asset f_time
   for f_symbol in BTC/$CURRENCY "${f_symbols_array_trade[@]}"
   do
     f_asset=${f_symbol//:$CURRENCY/}
     f_asset=${f_asset//\//}

     # week not available
     [[ $f_interval = 1w ]] && continue
     
     f_time='%Y-%m-%d %H:%M:00'
     [[ $f_interval = 1d ]] && f_time='%Y-%m-%d'
   
     # BINANCE_LONG_SHORT_RATIO_ACCOUNT per symbol
     get_marketdata BINANCE_LONG_SHORT_RATIO_ACCOUNT_$f_asset "https://fapi.binance.com/futures/data/globalLongShortAccountRatio?symbol=${f_asset}&limit=500&period=${f_interval}" ".[] | (.timestamp/1000 | strftime(\"${f_time}\")) + \",\" + .longShortRatio + \",,,,0\"" "" ${f_interval}
    
     # BINANCE_LONG_SHORT_RATIO_Taker per symbol
     get_marketdata BINANCE_LONG_SHORT_RATIO_TAKER_$f_asset "https://fapi.binance.com/futures/data/takerlongshortRatio?symbol=${f_asset}&limit=500&period=${f_interval}" ".[] | (.timestamp/1000 | strftime(\"${f_time}\")) + \",\" + .buySellRatio + \",,,,0\"" "" ${f_interval}

     # BINANCE_OPEN_INTEREST per symbol
     get_marketdata BINANCE_OPEN_INTEREST_$f_asset "https://fapi.binance.com/futures/data/openInterestHist?symbol=${f_asset}&limit=500&period=${f_interval}" ".[] | (.timestamp/1000 | strftime(\"${f_time}\")) + \",\" + .sumOpenInterest + \",,,,0\"" "" ${f_interval}

   done
}


function get_marketdata {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
 
  local f_name=$1
  local f_wget=$2
  local f_jq=$3
  local f_other=$4
  local f_timeframe=$5
  [ -z "$f_timeframe" ] && f_timeframe=1d
  local f_histfile="asset-histories/MARKETDATA_${f_name}.history.1d.csv"
  local f_dataline f_failed

  # download
  g_wget -O "${f_histfile}.wget.tmp" $f_wget 2>"${f_histfile}.err.tmp" || f_failed=wget
  [ -s "${f_histfile}.wget.tmp" ] || f_failed=wget
  if [ -n "$f_failed" ]
  then
    echo "g_wget -O \"${f_histfile}.wget.tmp\" $f_wget 2>\"${f_histfile}.err\"" >"${f_histfile}.err"
  fi

  # jd
  if [ -z "$f_failed" ] && [ -n "$f_jq" ]
  then
    if ! jq -r "$f_jq" "${f_histfile}.wget.tmp" >"${f_histfile}.tmp" 2>"${f_histfile}.err.tmp"
    then
      echo jq -r "$f_jq" "${f_histfile}.wget.tmp" >"${f_histfile}.err"
      f_failed=jq
    else
      mv "${f_histfile}.tmp" "${f_histfile}.wget.tmp"
    fi
  fi
 
  # other/additional processing
  if [ -z "$f_failed" ] && [ -n "$f_other" ]
  then
    if ! cat "${f_histfile}.wget.tmp" | eval $f_other
    then
      echo "cat \"${f_histfile}.wget.tmp\" | $f_other" >"${f_histfile}.err"
      f_failed=other
    fi
  else
    mv "${f_histfile}.wget.tmp" "${f_histfile}.tmp"
  fi


  # cleanup
  rm -f "${f_histfile}.wget.tmp" "${f_histfile}.err.tmp"

  # error if no csvfile available
  if [ -n "$f_failed" ] || ! [ -s "${f_histfile}.tmp" ]
  then
    cat "${f_histfile}.err.tmp" >>"${f_histfile}.err"
    cat "${f_histfile}.wget.tmp" >>"${f_histfile}.err"
    cat "${f_histfile}.err" 1>&2
    mkdir -p FAILED_MARKETDATA
    mv "${f_histfile}.err" "FAILED_MARKETDATA/MARKETDATA-${f_name}" 2>/dev/null
    return 1
  fi

  # on first download  
  if ! [ -s "${f_histfile}" ]
  then
    grep ^[2-9] "${f_histfile}.tmp" | sort -k1,1 -t, -u >"${f_histfile}"
  else
    # merge data
    egrep -h ^[0-9][0-9][0-9][0-9]-[0-9][0-9] "${f_histfile}" "${f_histfile}.tmp" | sort -k1,1 -t, -u >"${g_tmp}/${FUNCNAME}.tmp"

    # if there is new dataline add it
    if ! cmp -s "${g_tmp}/${FUNCNAME}.tmp" "${f_histfile}"
    then
      cat "${g_tmp}/${FUNCNAME}.tmp" >"${f_histfile}"
    fi
  fi
  rm "${f_histfile}.tmp"

  # calc indicators and if 1d then generate 1w histfile
  if [[ $f_interval = 1d ]]
  then
    get_indicators "${f_histfile}"
    convert_ohlcv_1d_to_1w "${f_histfile}" "${f_histfile/.1d./.1w.}"
    get_indicators "${f_histfile/.1d./.1w.}"
  else
    get_indicators "${f_histfile}" 999
  fi
}

