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

function get_marketdata_all {
  local f_interval=$1
  
  # daily marketdata jobs
  if [[ $f_interval = 1d ]]
  then
    # FEAR_AND_GREED_ALTERNATIVEME
    get_marketdata FEAR_AND_GREED_ALTERNATIVEME 'https://api.alternative.me/fng/?limit=0&format=json' '.data[] | .timestamp + "000," + .value + ",,,,0"' "" 1d

    # FEAR AND GREED COINMARKETCAP
    get_marketdata FEAR_AND_GREED_COINMARKETCAP "https://api.coinmarketcap.com/data-api/v3/fear-greed/chart?start=1&end=$(date +%s)" '.data.dataList[] | .timestamp + "000," + (.score|tostring) + ",,,,0"'

    # FEAR_AND_GREED_CNN
    get_marketdata FEAR_AND_GREED_CNN 'https://production.dataviz.cnn.io/index/fearandgreed/graphdata' '.fear_and_greed_historical.data[] | (.x|tostring) + "," + (.y|tostring) + ",,,,0"' "" 1d

    # Altcoin-Saison-Index COINMARKETCAP Top 100 Altcoins
    get_marketdata ALTCOIN_SEASON_INDEX_COINMARKETCAP "https://api.coinmarketcap.com/data-api/v3/altcoin-season/chart?start=1&end=$(date +%s)" '.data.points[:-1][] | .timestamp + "000," + (.altcoinIndex|tostring) + ",,,,0"' "" 1d

    # monthly US consumer price index CPI data
    get_marketdata US_CONSUMER_PRICE_INDEX_CPI "https://api.bls.gov/publicAPI/v2/timeseries/data/CUUR0000SA0?startyear=$(date -d 'now -8 years' '+%Y')&endyear=$(date '+%Y')" '.Results.series[0].data[] | .year + "-" + (.period | gsub("M"; ""))  + "-01," + .value + ",,,,0"' "" 1d

    # monthly US unemployment rate
    get_marketdata US_UNEMPLOYMENT_RATE "https://api.bls.gov/publicAPI/v2/timeseries/data/LNU03000000?startyear=$(date -d 'now -8 years' '+%Y')&endyear=$(date '+%Y')" '.Results.series[0].data[] | .year + "-" + (.period | gsub("M"; ""))  + "-01," + .value + ",,,,0"' "" 1d
  
    # US FED funds rate
    get_marketdata US_FED_FUNDS_RATE 'https://fred.stlouisfed.org/graph/fredgraph.csv?id=DFF' "" "" 1d

    # US M2 Money Supply seasonally-adjusted level
    get_marketdata US_FED_M2_SL_MONEY_SUPPLY 'https://fred.stlouisfed.org/graph/fredgraph.csv?chart_type=line&id=M2SL&fq=Monthly' "" "" 1M
    
    # US M2 Not sasonally-adjusted level
    get_marketdata US_FED_M2_NS_MONEY_SUPPLY 'https://fred.stlouisfed.org/graph/fredgraph.csv?chart_type=line&id=M2SL&fq=Monthly' "" "" 1M

  fi

   # Binance Long Short Ration Account / Taker and Open Interest per symbol
   get_symbols_ticker
   local f_symbol f_asset #f_time
   for f_symbol in BTC/$CURRENCY "${f_symbols_array_trade[@]}"
   do
     f_asset=${f_symbol//:$CURRENCY/}
     f_asset=${f_asset//\//}

     # week not available
     [[ $f_interval = 1w ]] && continue
     
     #f_time='%Y-%m-%d %H:%M:00'
     #[[ $f_interval = 1d ]] && f_time='%Y-%m-%d'
   
     # BINANCE_LONG_SHORT_RATIO_ACCOUNT per symbol
     get_marketdata BINANCE_LONG_SHORT_RATIO_ACCOUNT_$f_asset "https://fapi.binance.com/futures/data/globalLongShortAccountRatio?symbol=${f_asset}&limit=500&period=${f_interval}" ".[] | (.timestamp|tostring) + \",\" + .longShortRatio + \",,,,0\"" "" ${f_interval}
    
     # BINANCE_LONG_SHORT_RATIO_Taker per symbol
     get_marketdata BINANCE_LONG_SHORT_RATIO_TAKER_$f_asset "https://fapi.binance.com/futures/data/takerlongshortRatio?symbol=${f_asset}&limit=500&period=${f_interval}" ".[] | (.timestamp|tostring) + \",\" + .buySellRatio + \",,,,0\"" "" ${f_interval}

     # BINANCE_OPEN_INTEREST per symbol
     get_marketdata BINANCE_OPEN_INTEREST_$f_asset "https://fapi.binance.com/futures/data/openInterestHist?symbol=${f_asset}&limit=500&period=${f_interval}" ".[] | (.timestamp|tostring) + \",\" + .sumOpenInterest + \",,,,0\"" "" ${f_interval}

   done
}


function get_marketdata {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
 
  local f_name=$1
  local f_wget=$2
  local f_jq=$3
  local f_other=$4
  local f_timeframe=$5
  [[ -z "$f_timeframe" ]]  && f_timeframe=1d
  local f_histfile="asset-histories/MARKETDATA_${f_name}.history.${f_timeframe}.csv"
  local f_dataline f_failed

  # download
  g_wget -O "${f_histfile}.wget.tmp" $f_wget 2>"${f_histfile}.err.tmp" || f_failed=wget
  [[ -s "${f_histfile}.wget.tmp" ]]  || f_failed=wget
  if [[ -n "$f_failed" ]] 
  then
    echo "g_wget -O \"${f_histfile}.wget.tmp\" $f_wget 2>\"${f_histfile}.err\"" >"${f_histfile}.err"
  fi

  # jq
  if [[ -z "$f_failed" ]] && [[ -n "$f_jq" ]] 
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
  if [[ -z "$f_failed" ]] && [[ -n "$f_other" ]] 
  then
    if ! cat "${f_histfile}.wget.tmp" | eval $f_other
    then
      echo "cat \"${f_histfile}.wget.tmp\" | $f_other" >"${f_histfile}.err"
      f_failed=other
    fi
  else
    mv "${f_histfile}.wget.tmp" "${f_histfile}.tmp"
  fi

  # local timestamps
  if [[ $f_timeframe = 1d ]] 
  then 
    csv_timestamp_to_localtime "${f_histfile}.tmp" "%Y-%m-%d"
  else
    csv_timestamp_to_localtime "${f_histfile}.tmp"
  fi

  # cleanup
  rm -f "${f_histfile}.wget.tmp" "${f_histfile}.err.tmp"

  # error if no csvfile available
  if [[ -n "$f_failed" ]] || ! [[ -s "${f_histfile}.tmp" ]] 
  then
    cat "${f_histfile}.err.tmp" >>"${f_histfile}.err"
    cat "${f_histfile}.wget.tmp" >>"${f_histfile}.err"
    cat "${f_histfile}.err" 1>&2
    mkdir -p FAILED_MARKETDATA
    mv "${f_histfile}.err" "FAILED_MARKETDATA/MARKETDATA-${f_name}" 2>/dev/null
    return 1
  fi

  # create/edit histfile 
  if ! [[ -s "${f_histfile}" ]] 
  then
    # on first download
    g_echo_note "first download ${f_histfile}"
    #grep ^[2-9] "${f_histfile}.tmp" | sort -k1,1 -t, -u >"${f_histfile}"
  else
    # merge data
    g_echo_note "merge data ${f_histfile} ${f_histfile}.tmp"
    egrep -h ^[0-9][0-9][0-9][0-9]-[0-9][0-9] "${f_histfile}" "${f_histfile}.tmp" | sort -k1,1 -t, -u >"${g_tmp}/${FUNCNAME}.tmp"
    mv "${g_tmp}/${FUNCNAME}.tmp" "${f_histfile}"
  fi
  rm "${f_histfile}.tmp"

  # calc indicators and if 1d then generate 1w histfile
  if [[ $f_timeframe = 1d ]]
  then
    get_indicators "${f_histfile}" 51
    convert_ohlcv_1d_to_1w "${f_histfile}" "${f_histfile/.1d./.1w.}"
    get_indicators "${f_histfile/.1d./.1w.}" 51
  else
    get_indicators "${f_histfile}" 51
  fi
}

