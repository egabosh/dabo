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


function watch_assets {
  
  local f_watch_assets_array
  local f_line
  local f_price
  local f_alert
  local f_alert_html="<h2>Alerts when values are crossed</h2><table>"
  local f_portfolio_html="<h2>Portfolio</h2><table>"
  local f_last_price

  local f_html="<html>
<head>
  <meta charset='UTF-8'>
  <meta http-equiv='refresh' content='${INTERVAL}'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <link rel='stylesheet' type='text/css' href='/browser.css'>
  <link rel='stylesheet' type='text/css' href='/charts.min.css'>
  <title>Dabo WATCH ASSETS - ${URL}</title>
</head>
<body>
  <h1>Dabo-Bot WATCH ASSETS - ${URL} (ReadOnly)</h1>
  <h1>Last update $(date '+%F %T')</h1>"

  .watch_assets.sh.swp

  return 0
 
  mapfile -t f_watch_assets_array < <(egrep -v '^ASSET,ALERTS,BUYPRICE,BUYDATE,BUYQUANTITY,SELLPRICE,SELLDATE,SELLQUANTITY|^#|^$|^ +$' /dabo/watch-assets.csv)
  for f_line in "${f_watch_assets_array[@]}"
  do
    g_echo "$f_line"
    readarray -d "," -t f_line_array < <(echo -n "0,${f_line}")
    local f_asset=${f_line_array[1]}
    local f_alerts=${f_line_array[2]}
    local f_buyprice=${f_line_array[3]}
    local f_buydate=${f_line_array[4]}
    local f_buyquantity=${f_line_array[5]}
    local f_sellprice=${f_line_array[6]}
    local f_selldate=${f_line_array[7]}
    local f_sellquantity=${f_line_array[8]}
    local f_comment=${f_line_array[9]}
    local f_currency=${f_line_array[10]}

    [[ ${f_currency} =~ ^usd ]] && local f_currency_symbol="$"
    [[ ${f_currency} =~ ^eur ]] && local f_currency_symbol="€"

    # get current asset price and last price
    f_price=""
    if [[ ${f_asset} =~ ^https ]] || [[ ${f_asset} =~ " " ]]
    then
      # get asset price from get_marketdata_from_url
      get_marketdata_from_url ${f_asset}
      f_price=${f_get_marketdata_price}
      ### 2do USD->EUR Umrechnugn wenn f_currency=eur
      readarray -d " " -t f_asset_array < <(echo -n "${f_asset}")
      f_asset=${f_asset_array[1]}
    else
      # get token price from coingecko
      f_price=$(jq -r ".[] |select(.symbol==\"${f_asset}\")|\"\\(.current_price)\"" COINGECKO_GET_ASSETS_${f_currency}_CMD_OUT)
    fi
    [ -s WATCH_ASSETS_${f_asset}_${f_currency}_LAST_PRICE ] && read f_last_price < <(cat WATCH_ASSETS_${f_asset}_${f_currency}_LAST_PRICE)
    echo ${f_price} >WATCH_ASSETS_${f_asset}_${f_currency}_LAST_PRICE
    echo g_num_valid_number ${f_price} ${f_last_price} #|| continue

    # Notify on alert
    readarray -d "|" -t f_alerts_array < <(echo -n "${f_alerts}")
    for f_alert in "${f_alerts_array[@]}"
    do
       f_alert_html+="<tr><td>${f_asset}</td><td>${f_alert}</td></tr>" 
       if g_num_is_higher ${f_price} ${f_alert} && g_num_is_lower_equal ${f_last_price} ${f_alert}
       then
         g_signal-notify "${f_asset} Price ${f_price} switched over ${f_alert}! Comment: ${f_comment}"
       fi
       if g_num_is_lower ${f_price} ${f_alert} && g_num_is_higher_equal ${f_last_price} ${f_alert}
       then
         g_signal-notify "${f_asset} Price ${f_price} switched under ${f_alert}! Comment: ${f_comment}"
       fi
    done

    # List portfolio
    if [ -n "${f_buyprice}" ]
    then
     g_calc "${f_buyprice}*${f_buyquantity}"
     f_buyquantity_price=${g_calc_result}
     g_percentage-diff ${f_buyprice} ${f_price}
     
     local f_portfolio_html+="<tr><td>${f_asset} (${f_comment})</td><td>${f_buyquantity_price}${f_currency_symbol} (${f_buyprice}${f_currency_symbol})</td><td>${f_price}${f_currency_symbol}</td><td> ${g_percentage_diff_result}%</td></tr>"
     
    fi


  done

  f_alert_html+="</table>"
  f_portfolio_html+="</table>"
  echo ${f_html} ${f_portfolio_html} ${f_alert_html} | perl -pe 's/ (\-[0-9]+\.[0-9]+\%)/<font color=red>$1<\/font>/g; s/ ([0-9]+\.[0-9]+\%)/<font color=green>$1<\/font>/g;' >../watch.html

}
