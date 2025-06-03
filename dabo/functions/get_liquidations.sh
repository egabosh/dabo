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


function get_liquidations {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
 
  mkdir -p liquidations

  local f_timeframes="12h 1d 3d 1w 2w 1M" # 3M 6M 1y"
  local f_price f_liquidations f_date f_ldate f_upside_liquidity f_downside_liquidity f_upside_highest_price f_downside_highest_price f_liquiditydirection f_liquidityprice

  get_symbols_ticker

  if ! [[ -s /dabo/.coinank-secrets ]]
  then
    g_echo_note "No CoinAnk API Key in dabo/.coinank-secrets"
    return 0
  fi

  local f_curl_opts=( 
     --compressed
     -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:139.0) Gecko/20100101 Firefox/139.0'
     -H 'Accept: application/json, text/plain, */*'
     -H 'Accept-Language: de,en-US;q=0.7,en;q=0.3'
     -H 'Accept-Encoding: gzip, deflate, br, zstd'
     -H 'Referer: https://coinank.com/'
     -H 'client: web'
     -H 'token: '
     -H 'web-version: 101'
     -H 'Origin: https://coinank.com'
     -H 'DNT: 1'
     -H 'Sec-GPC: 1'
     -H 'Connection: keep-alive'
     -H 'Sec-Fetch-Dest: empty'
     -H 'Sec-Fetch-Mode: cors'
     -H 'Sec-Fetch-Site: same-site'
     -H 'Priority: u=0'
     -H 'Pragma: no-cache'
     -H 'Cache-Control: no-cache'
     -H 'TE: trailers'
   )

  set -o pipefail
  # get supported symbols if older then 1 day
  . "/dabo/.coinank-secrets"
  [[ -f liquidations/coinankSymbols ]] && [[ $(stat -c %Y liquidations/coinankSymbols) -gt $(( $(date +%s) - 1440*60 )) ]] || \
  curl -sS "${f_curl_opts[@]}" \
    -H "coinank-apikey: $coinank_apikey" \
    'https://api.coinank.com/api/liqMap/getLiqHeatMapSymbol' 2>liquidations/coinankSymbols.err | \
      jq -r '.data[]' >liquidations/coinankSymbols.new 2>>liquidations/coinankSymbols.err
  unset coinank_apikey
  set +o pipefail

  # report error wor write list down
  if [[ -s "liquidations/coinankSymbols.err" ]]
  then
    g_echo_warn "Error downloading CoinAnk LiqHeatMapSymbol list $(cat liquidations/coinankSymbols.new liquidations/coinankSymbols.err)"
    rm -f liquidations/coinankSymbols.new liquidations/coinankSymbols.err
  else
    [[ -s liquidations/coinankSymbols.new ]] && mv liquidations/coinankSymbols.new liquidations/coinankSymbols
  fi
  
  for f_symbol in ${f_symbols_array_trade[@]}
  do
    f_asset=${f_symbol//:$CURRENCY/}
    f_asset=${f_asset//\//}
    grep -q "^$f_asset$" liquidations/coinankSymbols

    for f_timeframe in $f_timeframes
    do
      # do nothing if target exists and isn't changes for 46 minutes
      [[ -f "liquidations/${f_asset}_$f_timeframe.csv" ]] && [[ $(stat -c %Y liquidations/${f_asset}_$f_timeframe.csv) -gt $(( $(date +%s) - 46*60 )) ]] && continue
  
      # wait random time
      sleep $(( RANDOM % 21 + 10 ))

      g_echo_note "Fetching Liquidations for $f_asset $f_timeframe from CoinAnk"

      [[ -z "$g_proxys" ]] && g_proxys="none"
      for g_proxy in $g_proxys
      do
        # get data from CoinAnk API
        . "/dabo/.coinank-secrets"
    
        f_proxy="--proxy $g_proxy"
        [[ $g_proxy = none ]] && f_proxy=""
        curl -sS "${f_curl_opts[@]}" \
          -H "coinank-apikey: $coinank_apikey" \
          $f_proxy \
          "https://api.coinank.com/api/liqMap/getLiqHeatMap?exchangeName=Binance&symbol=${f_asset}&interval=$f_timeframe" \
          >liquidations/${f_asset}_$f_timeframe.csv.new.json \
          2>liquidations/${f_asset}_$f_timeframe.csv.new.err || continue
        unset coinank_apikey
        grep -q '"success":false,"code":"403",' liquidations/${f_asset}_$f_timeframe.csv.new.json && continue
        grep -q '504 Gateway Time-out' liquidations/${f_asset}_$f_timeframe.csv.new.json && continue
        break
      done
      
      # parse/map json data
      jq -r '
        def map1: (.data.liqHeatMap.chartTimeArray | to_entries | map({("\(.key+1)"): .value}) | add);
        def map2: (.data.liqHeatMap.priceArray | to_entries | map({("\(.key+1)"): .value}) | add);

        (map1 as $m1 | map2 as $m2 |
          [ .data.liqHeatMap.data[] |
            [
              (($m1[.[0]] // .[0]) | tonumber / 1000 | strftime("%Y-%m-%d %H:%M:%S")),
              (($m1[.[0]] // .[0]) | tonumber),
              ($m2[.[1]] // .[1]),
              .[2]
            ]
          ] 
          | (map(.[1]) | max) as $max_time
          | map(select(.[1] == $max_time))
          | map([.[0], .[2], .[3]] | map(tostring) | join(","))
          | .[]
        )
      ' liquidations/${f_asset}_$f_timeframe.csv.new.json >liquidations/${f_asset}_$f_timeframe.csv.new 2>>liquidations/${f_asset}_$f_timeframe.csv.new.err
  
      # report error
      if [[ -s "liquidations/${f_asset}_$f_timeframe.csv.new.err" ]]
        then
        g_echo_warn "Error downloading liquidations ${f_asset} $f_timeframe $(cat liquidations/${f_asset}_$f_timeframe.csv.new.json liquidations/${f_asset}_$f_timeframe.csv.new liquidations/${f_asset}_$f_timeframe.csv.new.err 2>/dev/null)"
        rm -f liquidations/${f_asset}_$f_timeframe.csv.new liquidations/${f_asset}_$f_timeframe.csv.new.err
        grep -q '"success":false,"code":"403",' liquidations/${f_asset}_$f_timeframe.csv.new.json && return 1
        continue 2
      else
        mv liquidations/${f_asset}_$f_timeframe.csv.new liquidations/${f_asset}_$f_timeframe.csv
      fi
  
      # look if there is more upside or downside liquidity
      f_upside_liquidity=1
      f_downside_liquidity=1
      f_upside_highest=1
      f_downside_highest=1
      while IFS=, read -r f_ldate f_price f_liquidations
      do
        if g_num_is_higher "$f_price" "${v[${f_asset}_price]}"
        then
          g_calc "$f_upside_liquidity + $f_liquidations"
          f_upside_liquidity=$g_calc_result
          if g_num_is_higher $f_liquidations $f_upside_highest
          then 
            f_upside_highest=$f_liquidations
            f_upside_highest_price=$f_price
          fi
        else
          g_calc "$f_downside_liquidity + $f_liquidations"
          f_downside_liquidity=$g_calc_result
          if g_num_is_higher $f_liquidations $f_downside_highest
          then
            f_downside_highest=$f_liquidations
            f_downside_highest_price=$f_price
           fi
        fi
        f_date=$f_ldate
      done < liquidations/${f_asset}_$f_timeframe.csv

      if g_num_is_higher $f_upside_liquidity $f_downside_liquidity
      then
        g_percentage-diff $f_upside_liquidity $f_downside_liquidity
        f_liquiditydirection="upsideliquidity"
        f_liquidityprice=$f_upside_highest_price
      else
        g_percentage-diff $f_downside_liquidity $f_upside_liquidity
        f_liquiditydirection="downsideliquidity"
        f_liquidityprice=$f_downside_highest_price
      fi
      echo "$f_date,$f_liquiditydirection,$f_liquidityprice,${g_percentage_diff_result#-},$f_upside_highest_price,$f_downside_highest_price" >>"asset-histories/${f_asset}.history.1h.liquidity_${f_timeframe}.csv"

  
    done
  done
}
