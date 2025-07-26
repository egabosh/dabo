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


function webpage {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  #webpage_transactions
  get_symbols_ticker
  charts

  # create status webpage
  echo "<html>
<head>
  <meta charset='UTF-8'>
  <meta http-equiv='refresh' content='${INTERVAL}'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <link rel='stylesheet' type='text/css' href='/browser.css'>
  <link rel='stylesheet' type='text/css' href='/charts.min.css'>
  <title>Dabo! on ${STOCK_EXCHANGE} - ${URL}</title>
</head>
<body>
  <h1>State of Dabo-Bot! on ${STOCK_EXCHANGE} - ${URL} (ReadOnly)</h1>
  <h1>Last update $(date '+%F %T')</h1>" >../index.html.tmp

  # balance
  local f_USED_BALANCE=$(tail -n1 "asset-histories/BALANCEUSED${CURRENCY}.history.csv" | cut -d, -f2)
  local f_COMPLETE_BALANCE=$(tail -n1 "asset-histories/BALANCECOMPLETE${CURRENCY}.history.csv" | cut -d, -f2)
  g_calc "$f_COMPLETE_BALANCE-$f_USED_BALANCE"
  printf -v CURRENCY_BALANCE %.2f $g_calc_result
  echo '<h2>Overview</h2>' >>../index.html.tmp
  echo "<table>
  <tr>
   <td><b>Overall Balance:</b></td>
   <td><font color=green><b>${CURRENCY} ${f_COMPLETE_BALANCE}</b></font></td>
  </td>
  <tr>
   <td>Used Balance (invested):</td>
   <td><font color=blue>${CURRENCY} $f_USED_BALANCE</font></td>
  </tr>
  <tr>
   <td>Free Balance (not invested):</td>
   <td><font color=yellow>${CURRENCY} ${CURRENCY_BALANCE}</font></td>
  </tr>
  </table>" >>../index.html.tmp

  echo "<h2>Balance in- outflows</h2>" >>../index.html.tmp
  echo "<table><tr class=\"headline\"><td><b>Time ago</b><td><b>Balance</b></td><td><b>in/out</b></td><td><b>Percentage</b></td></tr>" >> ../index.html.tmp

  for f_balance_date in Day Week Month 3Month Year
  do
    f_balance_at_date=$(grep "^$(date -d "1 $f_balance_date ago" +"%Y-%m-%d ")" asset-histories/BALANCECOMPLETE${CURRENCY}.history.csv | head -n1 | cut -d, -f2)
    if g_num_valid_number "$f_balance_at_date" 2>/dev/null
    then
      printf -v f_balance_at_date %.2f $f_balance_at_date
      g_calc "$f_COMPLETE_BALANCE-$f_balance_at_date"
      printf -v f_balance_diff %.2f $g_calc_result
      g_percentage-diff $f_balance_at_date $f_COMPLETE_BALANCE
      printf -v f_balance_diff_percentage %.2f $g_percentage_diff_result
      echo "<tr><td>$f_balance_date<td>$f_balance_at_date</td><td>$f_balance_diff</td><td> ${f_balance_diff_percentage}%</td></tr>" >> ../index.html.tmp
    fi
  done
  echo "</table>" >>../index.html.tmp


  echo '<h2>Open Positions</h2>' >>../index.html.tmp
  echo "<table width='100%'><tr class=\"headline\"><td>Symbol</td><td>Amount</td><td>Entry Price</td><td>Current Price</td><td>Profit/Loss</td><td>Liquidation Price</td><td>StopLoss</td><td>TakeProfit</td><td>Notes</td></tr>" >>../index.html.tmp
  get_position_array
  for f_symbol in ${f_symbols_array_trade[@]}
  do
    f_asset=${f_symbol//:$CURRENCY/}
    f_asset=${f_asset//\//}
    [[ -z "${p[${f_asset}_entry_price]}" ]]  && continue
    echo "<tr>
<td><a href=\"charts.html?symbol=${f_asset}&time=4h&symbol2=BTCUSDT\" target=\"_blank\" rel=\"noopener noreferrer\">$f_symbol</a></td>
<td>${p[${f_asset}_currency_amount]}</td>
<td>${p[${f_asset}_entry_price]}</td>
<td>${p[${f_asset}_current_price]}</td>
<td>${p[${f_asset}_pnl]} ( ${p[${f_asset}_pnl_percentage]}%)</td>
<td>${p[${f_asset}_liquidation_price]}</td>
<td>${p[${f_asset}_stoploss_price]}</td>
<td>${p[${f_asset}_takeprofit_price]}</td>
<td>${p[${f_asset}_side]} ${p[${f_asset}_leverage]}x</td>
</tr>" >>../index.html.tmp
  done
  echo "</table>" >>../index.html.tmp


  echo '<h2>Open Orders</h2>' >>../index.html.tmp
  echo "<table width='100%'><tr class=\"headline\"><td>Symbol</td><td>Amount</td><td>Entry Price</td><td>StopLoss</td><td>TakeProfit</td><td>Notes</td></tr>" >>../index.html.tmp
  get_orders_array
  local f_id
  for f_symbol in ${f_symbols_array_trade[@]}
  do
    f_asset=${f_symbol//:$CURRENCY/}
    f_asset=${f_asset//\//}
    for f_id in ${o[${f_asset}_ids]}
    do
      [[ ${o[${f_asset}_${f_id}_type]} == @(MarketIfTouched|LimitIfTouched) ]] && continue
      [[ ${o[${f_asset}_${f_id}_type]} == Stop ]] && continue
      echo "<tr>
<td><a href=\"charts.html?symbol=${f_asset}&time=4h&symbol2=BTCUSDT\" target=\"_blank\" rel=\"noopener noreferrer\">$f_symbol</a></td>
<td>${o[${f_asset}_${f_id}_amount]}</td>
<td>${o[${f_asset}_${f_id}_entry_price]}</td>
<td>${o[${f_asset}_${f_id}_stoplossprice]}</td>
<td>${o[${f_asset}_${f_id}_takeprofitprice]}</td>
<td>${f_id} ${o[${f_asset}_${f_id}_type]} ${o[${f_asset}_${f_id}_side]}</td>
</tr>" >>../index.html.tmp
   done
  done
  echo "</table>" >>../index.html.tmp

  ## charts
  echo '<h2>Charts with local data</h2><p>Click on time units to open chart</p>' >>../index.html.tmp
  
  local eco_assets=$(echo " $ECO_ASSETS" | sed 's/ / ECONOMY-/g')
  for f_symbol in ${f_symbols_array_trade[@]} $eco_assets
  do
    f_asset=${f_symbol//:$CURRENCY/}
    f_asset=${f_asset//\//}
    echo "$f_asset: " >>../index.html.tmp
    for f_timeframe in 1w 1d 4h 1h 15m
    do
      echo "<td><a href=\"charts.html?symbol=${f_asset}&time=${f_timeframe}&symbol2=BTCUSDT\" target=\"_blank\" rel=\"noopener noreferrer\"}>${f_timeframe}</a>" >>../index.html.tmp
    done
    echo "<br>" >>../index.html.tmp
  done

  ## Open Positions
  echo "<h2>Open Positions - from other Exchanges</h2>
<p>Crypto-Only from Bitpanda and JustTrade - daily refresh</p>" >>../index.html.tmp
  echo "<table width='100%'>" >>../index.html.tmp
  echo "<tr class=\"headline\"><td>Date</td><td>Amount</td><td>Spent Amount</td><td>Profit/Loss</td><td>Asset Amount</td><td>Exchange</td></tr>" >>../index.html.tmp
  rm -f ../index.html.tmp.tmp
  local f_result_complete=0
  local f_spent_complete=0
  local f_currency_amount_complete=0
  local f_sold_complete=0
  local f_result_percent_complete=0
  local f_asset f_exchange f_amount f_spent f_sold f_currency_amount f_result_percent
  for f_asset_per_exchange in $(cat ALL_TRANSACTIONS_OVERVIEW.csv 2>/dev/null | cut -d, -f2,4 | sort -u)
  do
    mapfile -d, -t f_asset_per_exchange_array < <(echo $f_asset_per_exchange)
    f_asset=${f_asset_per_exchange_array[1]%$'\n'}
    f_exchange=${f_asset_per_exchange_array[0]}
    [[ "$f_exchange" =~ JustTrade|Bitpanda ]] || continue
    
    f_date=$(\
     cut -d, -f 1,2,4,8 ALL_TRANSACTIONS_OVERVIEW.csv | \
     egrep "$f_exchange,$f_asset,0$" | \
     tail -n1 | \
     cut -d, -f1 \
    )
    if [[ -z "$f_date" ]] 
    then
      egrep "$f_exchange,.+,$f_asset," ALL_TRANSACTIONS_OVERVIEW.csv >WEBPAGE-$f_exchange-$f_asset-OPEN_POS
      f_date=$(head -n1 WEBPAGE-$f_exchange-$f_asset-OPEN_POS | cut -d, -f1)
    else
      egrep "$f_exchange,.+,$f_asset," ALL_TRANSACTIONS_OVERVIEW.csv | \
       egrep -v -A999 "^$f_date" >WEBPAGE-$f_exchange-$f_asset-OPEN_POS
    fi

    f_amount=$(\
     cut -d, -f5 WEBPAGE-$f_exchange-$f_asset-OPEN_POS | \
     awk '{ sum += $1 } END { print sum }' \
    )
    g_num_exponential2normal "$f_amount"
    f_amount=$g_num_exponential2normal_result
    f_spent=$(\
     egrep -v 'reward-staking|giveaway|instant_trade_bonus' WEBPAGE-$f_exchange-$f_asset-OPEN_POS | \
     cut -d, -f7 | \
     awk '{ sum += $1 } END { print sum }' \
    )
    [[ -z "$f_spent" ]]  && f_spent=0
    if ! [[ "$f_amount" = 0 ]] 
    then
      currency_converter "$f_amount" "$f_asset" "$TRANSFER_CURRENCY" || continue
      printf -v f_price_today "%.2f" $f_currency_converter_result

      g_calc "$f_spent+$f_price_today"
      f_pnl=$g_calc_result

      g_percentage-diff "${f_spent#-}" $f_price_today
      f_pnl_percent=$g_percentage_diff_result
      [[ -z "$f_pnl_percent" ]]  && f_pnl_percent="99.99"

      echo "<tr><td>$f_date</td><td>$f_price_today $TRANSFER_CURRENCY</td><td>${f_spent#-} $TRANSFER_CURRENCY</td><td>$f_pnl $TRANSFER_CURRENCY ( ${f_pnl_percent}%)</td><td>$f_amount $f_asset</td><td>$f_exchange</td></tr>" >>../index.html.tmp.tmp
    fi
  done

  #g_percentage-diff $f_spent_complete $f_currency_amount_complete
  #f_result_percent_complete=$g_percentage_diff_result
  #
  ## ALL Line
  #echo "<tr><td>-</td><td>$f_currency_amount_complete $TRANSFER_CURRENCY</td><td>$f_spent_complete $TRANSFER_CURRENCY</td><td>$f_sold_complete $TRANSFER_CURRENCY</td><td>$f_result_complete $TRANSFER_CURRENCY ( ${f_result_percent_complete}%)</td><td>ALL</td><td>ALL</td></tr>" >>../index.html.tmp
  
  # Sort by Spent Amount
  [[ -s ../index.html.tmp.tmp ]]  && sort  -n -k7 -t'>' -r ../index.html.tmp.tmp >>../index.html.tmp
  rm -f ../index.html.tmp.tmp
  echo "</table>" >>../index.html.tmp


  # LSTM Predictions
  if [[ -n "$DOLSTM" ]] 
  then
  local f_lstm_file
  local f_date f_prediction f_real f_rsme_train f_rsme_test f_epochs f_batch_size f_train_ratio f_look_back f_patience f_lstm_units f_dropout_rate f_dense_units
  echo "<h2>LSTM Predictions</h2>" >>../index.html.tmp
  ls asset-histories/*${CURRENCY}.history.*.lstm_prediction.csv 2>/dev/null | while read f_lstm_file
  do
    f_symbol=${f_lstm_file#*/}
    f_symbol=${f_symbol%%.*}
    f_timeframe=${f_lstm_file#*history.}
    f_timeframe=${f_timeframe%%.*}
    echo "<h3>$f_symbol $f_timeframe</h3>" >>../index.html.tmp
    # Table
    echo "<table>
    <tr class=\"headline\">
      <td>Date</td>
      <td>Prediction</td>
      <td>Real</td>
      <td>RSME Train Score</td>
      <td>RSME Test Score</td>
      <td>epochs</td>
      <td>batch_size</td>
      <td>train_ratio</td>
      <td>look_back</td>
      <td>patience</td>
      <td>lstm_units</td>
      <td>dropout_rate</td>
      <td>dense_units</td>
      <td>Trainigdata</td>
    </tr>" >>../index.html.tmp
    tail -n 10 "$f_lstm_file" | while IFS=',' read -r f_date f_prediction f_rsme_train f_rsme_test f_epochs f_batch_size f_train_ratio f_look_back f_patience f_lstm_units f_dropout_rate f_dense_units
    do
      [[ "${f_timeframe}" = 1d ]]  && f_date=$(date -d "$f_date + 1 day" +"%Y-%m-%d")
      [[ "${f_timeframe}" = 1w ]]  && f_date=$(date -d "$f_date + 1 week" +"%Y-%m-%d")
      f_real=$(grep "^$f_date," asset-histories/${f_symbol}.history.${f_timeframe}.csv | tail -n1 | cut -d, -f5)
        echo "  <tr>"
        echo "    <td>$f_date</td>"
        echo "    <td>$f_prediction</td>"
        echo "    <td>$f_real</td>"
        echo "    <td>$f_rsme_train</td>"
        echo "    <td>$f_rsme_test</td>"
        echo "    <td>$f_epochs</td>"
        echo "    <td>$f_batch_size</td>"
        echo "    <td>$f_train_ratio</td>"
        echo "    <td>$f_look_back</td>"
        echo "    <td>$f_patience</td>"
        echo "    <td>$f_lstm_units</td>"
        echo "    <td>$f_dropout_rate</td>"
        echo "    <td>$f_dense_units</td>"
        echo "    <td><a href='botdata/asset-histories/$f_symbol.history.$f_timeframe.lstm_prediction.trainingdata.csv'>download CSV</a></td>"
        echo "  </tr>"
    done >>../index.html.tmp
    echo "</table>" >>../index.html.tmp
  done
  fi


  # Closed positions
  echo "<h2>Closed Positions and (german) tax declaration notes</h2>" >>../index.html.tmp
  ls ../TRANSACTIONS_OVERVIEW-* | while read f_html
  do
    f_html=$(basename $f_html)
    f_name=$(echo $f_html | cut -d- -f2,3 | cut -d. -f1)
    echo "<a href='${f_html}'>$f_name</a><br>" >>../index.html.tmp
  done
  #echo "$(cat ALL_TRANSACTIONS_OVERVIEW_WARN.csv | cut -d, -f1,2,20)<br>" >>../index.html.tmp

  # THE END
  echo "</body></html>" >>../index.html.tmp

  # color magic
  cat ../index.html.tmp | perl -pe 's/ (\-[0-9]+\.[0-9]+\%)/<font color=red>$1<\/font>/g; s/ ([0-9]+\.[0-9]+\%)/<font color=green>$1<\/font>/g; s/ (\-[0-9]+\%)/<font color=red>$1<\/font>/g; s/ ([0-9]+\%)/<font color=green>$1<\/font>/g;' >../index.html

}

