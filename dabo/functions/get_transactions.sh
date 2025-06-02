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


function get_transactions {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_exchange f_symbol f_symbol_file f_asset f_currency f_leverage f_convert_end_month f_convert_end_year f_symbol_file_csv f_symbol_file_csv_tmp f_start_date f_end_date f_convert_file f_fiat f_fiats f_return
  local DEFAULT_STOCK_EXCHANGE=$STOCK_EXCHANGE
  local DEFAULT_LEVERAGE=$LEVERAGE


  for f_exchange in /dabo/.*-secrets;
  do
    # extract ccxt exchange from filename
    g_basename $f_exchange
    f_exchange=${g_basename_result/-secrets}
    f_exchange=${f_exchange/.}
    STOCK_EXCHANGE=$f_exchange
    
    [[ $f_exchange = bitpanda ]] && continue
    [[ $f_exchange = onetrading ]] && continue

    g_echo_note "Exchange: $f_exchange"

    # refetch symbols if not default exchange
    if ! [[ $DEFAULT_STOCK_EXCHANGE = $STOCK_EXCHANGE ]]
    then
      unset LEVERAGE
      get_symbols_ticker refetchonly
      LEVERAGE=$DEFAULT_LEVERAGE
    fi
 
    # load symbols to array
    get_symbols_ticker

    # transfer-dir
    mkdir -p "TRANSACTIONS-$f_exchange"
    # create timestamp file
    touch --time=mtime -t $(date -d "now -1 day" +%Y%m%d%H%M) TRANSACTIONS-TIMESTAMP

    # all symbols or onl trade smybols (faster)
    local f_symbols=("${f_symbols_array_trade[@]}")
    [[ $1 == all ]] && f_symbols=("${f_symbols_array[@]}")

    # go through symbols
    for f_symbol in "${f_symbols[@]}"
    do
 
      # binance does not allow derivate trading in many countries so ignore because of 400-Error
      [[ $f_symbol =~ : ]] && [[ $f_exchange = binance ]] && continue
      f_symbol_file="TRANSACTIONS-$f_exchange/${f_symbol//\/}"
      
      # remove file older then 1 day and refetch
      if [[ $1 == all ]] 
      then
        [[ "$f_symbol_file" -ot TRANSACTIONS-TIMESTAMP ]]  && rm -f "$f_symbol_file"
      else
        rm -f "$f_symbol_file"
      fi
      
      # fetch only if not exists
      [[ -f "$f_symbol_file" ]]  && continue
      g_echo_note "fetching closed orders of $f_symbol on ${STOCK_EXCHANGE}"

      # fetch and reset/store return code
      f_return=""
      f_ccxt "print(${STOCK_EXCHANGE}.fetchMyTrades(symbol='$f_symbol', limit=500, params={'paginate': True}))" || f_return=1

      # write result even if its failed/empty for timestamp
      echo -n $f_ccxt_result >"$f_symbol_file"

      # continue if fetch failed/empty
      if [[ -n "$f_return" ]] 
      then
        g_echo_note "fetch of $f_symbol on ${STOCK_EXCHANGE} failed no json output or empty - no trades"
        continue
      fi

      # check output for symbol
      if ! [[ $f_ccxt_result =~ $f_symbol ]]
      then
        g_echo_warn "unexpectet return in \"$f_symbol_file\" Symbol $f_symbol not present!?"
        continue
      fi
      
      # get f_asset+f_currency from symbol (BTC/USDT)
      g_array "$f_symbol" f_symbol_array /
      f_asset=${f_symbol_array[0]}
      f_currency=${f_symbol_array[1]}

      f_symbol_file_csv_tmp="${f_symbol_file}.csv.tmp"
      f_symbol_file_csv="${f_symbol_file}.csv"      
      >"${f_symbol_file_csv_tmp}"

      # Check for contract/leverage Trade
      f_leverage=""
      if [[ $f_currency =~ : ]]
      then
        # mark
        f_leverage="leverage-"

        # get funding fees
        f_ccxt "print(${STOCK_EXCHANGE}.fetchFundingHistory('$f_symbol', limit=200, params={'paginate': True}))" && echo -n $f_ccxt_result >"${f_symbol_file}.FundingFees"
        cat ${f_symbol_file}.FundingFees | jq -r "
.[] |
.datetime + \",fundingfee,$f_asset,0,\" + .code  + \",0\" + \",$f_exchange,\" + .code  + \",\" + (.amount|tostring) 
" >>$f_symbol_file_csv_tmp
        
        # remove the ':' in f_currency
        g_array "$f_currency" f_currency_array :
        f_currency=${f_currency_array[0]}
      fi

      # generate csv

      # get spot buy/sell (posSide=="1")
      cat "$f_symbol_file" | jq -r "
.[] |
 select(.side==\"buy\" or .side==\"sell\") |
 select(.symbol != null) |
.datetime + \",$f_leverage\" + .side + \",$f_asset,\" + (.amount|tostring) + \",$f_currency,\" + (.cost|tostring) + \",$f_exchange,\" + .fee.currency  + \",\" +  (.fee.cost|tostring) + \",\" +  .id
" >>"$f_symbol_file_csv_tmp"

#      # get longs (posSide=="1")
#      cat "$f_symbol_file" | jq -r "
#.[] |
# select(.side==\"buy\" or .side==\"sell\") |
# select(.info.posSide=\"1\") |
# select(.symbol!= null) |
#.datetime + \",$f_leverage\" + .side + \",$f_asset,\" + (.amount|tostring) + \",$f_currency,\" + (.cost|tostring) + \",$f_exchange,\" + .fee.currency  + \",\" +  (.fee.cost|tostring) + \",\" +  .id
#" >>"$f_symbol_file_csv_tmp"
#
#      # get shorts (posSide=="2") sell first, then buy (https://github.com/ccxt/ccxt/issues/22518)
#      cat "$f_symbol_file" | jq -r "
#.[] |
# select(.side==\"buy\" or .side==\"sell\") |
# select(.info.posSide==\"2\") |
# select(.symbol!=null) |
#.datetime + \",$f_leverage\" + .side + \",$f_asset,\" + (.amount|tostring) + \",$f_currency,\" + (.cost|tostring) + \",$f_exchange,\" + .fee.currency  + \",\" +  (.fee.cost|tostring) + \",\" +  .id
#" >>"$f_symbol_file_csv_tmp"

      if [[ -s "$f_symbol_file_csv_tmp" ]]  
      then
        if [[ -s "$f_symbol_file_csv" ]] 
        then
          cat "$f_symbol_file_csv_tmp" "$f_symbol_file_csv" | sort -u >"${f_symbol_file_csv}.sorted"
          mv "${f_symbol_file_csv}.sorted" "$f_symbol_file_csv"
          rm "$f_symbol_file_csv_tmp"
        else
          mv "$f_symbol_file_csv_tmp" "$f_symbol_file_csv"
        fi
      else
        rm "$f_symbol_file_csv_tmp"
      fi

    done

    ## Get converts on supported exchanges since 2022
    if [[ $f_exchange = binance ]]
    then
    local m y
    printf -v f_convert_end_year '%(%Y)T'
    for ((y=2022;y<=$f_convert_end_year;y++))
    do
      f_convert_end_month=12
      [[ $y == $f_convert_end_year ]] && printf -v f_convert_end_month '%(%m)T'
      for ((m=1;m<=$f_convert_end_month;m++))
      do
        f_start_date="$(date -d "$y-$m-1" +%s)001"
        #em=$((m+1))
        #[ $em = 13 ] && em=1
        #f_aend_date="$(date -d "$y-$em-1" +%s)000"
        f_end_date="$(date -d "$y-$m-1 +29days" +%s)000"
        f_convert_file="TRANSACTIONS-$f_exchange/CONVERT-$y-$m"

        [[ -s "${f_convert_file}.csv" ]]  && continue

        f_ccxt "print(${f_exchange}.fetchConvertTradeHistory(since=${f_start_date}, params={'until': ${f_end_date}}))" || f_ccxt_result=""
        echo -n $f_ccxt_result >"$f_convert_file"

        if [[ -s "$f_convert_file" ]] 
        then
          cat "$f_convert_file" | jq -r "
.[] |
 select(.info.side==\"BUY\") |
 .datetime + \",\" + (.info.side|ascii_downcase) + \",\" + .toCurrency + \",\" + (.toAmount|tostring) + \",\" + .fromCurrency + \",\" + (.fromAmount|tostring) + \",$f_exchange\"
" >"${f_convert_file}.csv"
          cat "$f_convert_file" | jq -r "
.[] |
 select(.info.side==\"SELL\") |
 .datetime + \",\" + (.info.side|ascii_downcase) + \",\" + .fromCurrency + \",\" + (.fromAmount|tostring) + \",\" + .toCurrency + \",\" + (.toAmount|tostring) + \",$f_exchange\"
" >>"${f_convert_file}.csv"

        fi
      done
    done
    fi

    # put all sorted in one file. duplicates check with id
    local f_line f_date f_sym
    touch "TRANSACTIONS-$f_exchange.csv"
    grep -vh ,fundingfee, "TRANSACTIONS-$f_exchange/"*.csv | while read f_line
    do
      f_id=$(echo "$f_line" | cut -d, -f10)
      grep -q "$f_id" "TRANSACTIONS-$f_exchange.csv" || echo $f_line >>"TRANSACTIONS-$f_exchange.csv" 
    done
    grep -h ,fundingfee, "TRANSACTIONS-$f_exchange/"*.csv | while read f_line
    do
      f_date=$(echo "$f_line" | cut -d: -f1)
      f_sym=$(echo "$f_line" | cut -d, -f3)
      egrep -q "^$f_date:.+,$f_sym," "TRANSACTIONS-$f_exchange.csv" || echo $f_line >>"TRANSACTIONS-$f_exchange.csv"
    done

    # Switch sides if Fiat is in Krypto side
    f_fiats="USD EUR"
    for f_fiat in $f_fiats
    do
      [[ -f TRANSACTIONS-$f_exchange.csv.tmp ]]  && rm TRANSACTIONS-$f_exchange.csv.tmp
      grep -h ",sell,$f_fiat," TRANSACTIONS-$f_exchange.csv | awk -F, '{print $1",buy,"$5","$6","$3","$4","$7","$8","$9}' >>TRANSACTIONS-$f_exchange.csv.tmp
      grep -h ",buy,$f_fiat," TRANSACTIONS-$f_exchange.csv | awk -F, '{print $1",sell,"$5","$6","$3","$4","$7","$8","$9}' >>TRANSACTIONS-$f_exchange.csv.tmp
      if [[ -s TRANSACTIONS-$f_exchange.csv.tmp ]] 
      then
        g_echo_note "Switched some fiat/krypto sides"
        #cat TRANSACTIONS-$f_exchange.csv.tmp
        cat TRANSACTIONS-$f_exchange.csv | egrep -v ",sell,$f_fiat,|,buy,$f_fiat," >>TRANSACTIONS-$f_exchange.csv.tmp
        cat TRANSACTIONS-$f_exchange.csv.tmp >TRANSACTIONS-$f_exchange.csv
      fi
    done

  done
  STOCK_EXCHANGE=$DEFAULT_STOCK_EXCHANGE

}

