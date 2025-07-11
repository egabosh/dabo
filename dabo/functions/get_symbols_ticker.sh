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


function get_symbols_ticker {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_fetch=$1
  local f_symbols t_symbol f_asset

  ## determine assets with prices
  [[ ${STOCK_EXCHANGE} = "NONE" ]]  && return 0

  # refetch from exchange
  if [[ "$f_fetch" = "refetchonly" ]] 
  then
    # fetch from exchange
    rm -f CCXT_TICKERS-${STOCK_EXCHANGE}.tmp 
    f_ccxt "print(${STOCK_EXCHANGE}.fetch_tickers())" && echo $f_ccxt_result  >CCXT_TICKERS_RAW-${STOCK_EXCHANGE}

    # parse relevant tokens
    local f_grep="${CURRENCY},"
    [[ -n "$LEVERAGE" ]]  && f_grep="${CURRENCY}:${CURRENCY},"
    [[ -s CCXT_TICKERS_RAW-${STOCK_EXCHANGE} ]]  && jq -r '.[] | .symbol + "," + (.last|tostring)' CCXT_TICKERS_RAW-${STOCK_EXCHANGE} | grep "${f_grep}" | egrep ".+,[0-9]" >CCXT_TICKERS-${STOCK_EXCHANGE}.tmp
  
    if [[ -s CCXT_TICKERS-${STOCK_EXCHANGE}.tmp ]]  
    then
      cat CCXT_TICKERS-${STOCK_EXCHANGE}.tmp >CCXT_TICKERS-$STOCK_EXCHANGE    
      cut -d, -f1 CCXT_TICKERS-${STOCK_EXCHANGE}.tmp >CCXT_SYMBOLS-${STOCK_EXCHANGE}

      ## get symbols by volume from history files and check with CCXT_SYMBOLS-$STOCK_EXCHANGE
      [[ -n "$LEVERAGE" ]]  && f_naming="${CURRENCY}:${CURRENCY}"
      tail -n1 asset-histories/*.history.1w.csv 2>/dev/null \
       | perl -pe "s/<==\n//; s/==> //; s/\.csv /,/g; s/\//./; s/$CURRENCY\.history\.1w/\/${f_naming}./" \
       | grep ",$(date +%Y)-" \
       | sort -r -n -t, -k7 \
       | cut -d. -f2 \
        >CCXT_SYMBOLS-$STOCK_EXCHANGE-by-volume.tmp
      # add mising (not yet fetched) symbols
      awk 'NR==FNR{a[$0];next} !($0 in a)' CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume.tmp CCXT_SYMBOLS-$STOCK_EXCHANGE >>CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume.tmp
      # remove (no more) existing symbols
      awk 'NR==FNR{a[$0];next} !($0 in a)' CCXT_SYMBOLS-$STOCK_EXCHANGE CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume.tmp \
       | while read f_remove_symbol
      do 
        echo "sed -i \"\\#${f_remove_symbol}#d\" CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume.tmp"
        sed -i "\#${f_remove_symbol}#d" CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume.tmp
      done
      # write final volume file
      [[ -s CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume.tmp ]]  && mv CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume.tmp CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume


      # write file with symbols that should be traded
      rm -f CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume-trade.tmp
      for f_symbol in $SYMBOLS
      do
        grep "^$f_symbol/$CURRENCY" CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume >>CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume-trade.tmp
      done
      [[ -s CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume-trade.tmp ]]  && mv CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume-trade.tmp CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume-trade
   
    else
      return 1
    fi
    
    return 0
  fi
  
  # create associative ticker array
  if [[ -s CCXT_TICKERS-$STOCK_EXCHANGE ]] 
  then
    g_array CCXT_TICKERS-$STOCK_EXCHANGE f_tickers_array_ref
    local f_ticker f_symbol f_price
    declare -Ag f_tickers_array
    declare -Ag v
    declare -Ag vr
    for f_ticker in "${f_tickers_array_ref[@]}"
    do
      f_symbol=${f_ticker%%:*}
      f_symbol=${f_symbol//\/}
      #f_symbol=${f_symbol/ /}
      f_price=${f_ticker/*,/}
      g_num_exponential2normal $f_price && f_price=$g_num_exponential2normal_result
      f_tickers_array[$f_symbol]=$f_price
      vr[${f_symbol}_price]=$f_price
      v[${f_symbol}_price]=$f_price
    done
  fi

  # create array with ccxt symbols sorted by volume
  [[ -s CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume ]]  && g_array CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume f_symbols_array_ref
  f_symbols_array=("${f_symbols_array_ref[@]}")

  # create array with ccxt symbols sorted by volume which sould be traded
  [[ -s CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume-trade ]]  && g_array CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume-trade f_symbols_array_trade_ref
  f_symbols_array_trade=("${f_symbols_array_ref[@]}")

  # create ASSETS array BTC/USDT:USDT -> BTCUSDT
  unset ASSETS
  for f_symbol in "${f_symbols_array_trade[@]}"
  do
    f_asset=${f_symbol//:$CURRENCY/}
    f_asset=${f_asset//\//}
    ASSETS+=("$f_asset")
  done

  # create f_symbols var
  [[ -s CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume ]]  && f_symbols=$(cat CCXT_SYMBOLS-${STOCK_EXCHANGE}-by-volume)
  f_symbols=${f_symbols//$'\n'/'+'}

  if [[ -z "$f_symbols" ]] 
  then
    if [[ "$f_fetch" = "retry" ]] 
    then
      g_echo_warn "Could not get symbols list - empty"
      return 1
    fi
    sleep 5
    g_echo_note "Could not get symbols list - empty - retrying"
    get_symbols_ticker retry || return 1
  fi

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@ END"

}

