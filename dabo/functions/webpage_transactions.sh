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


function webpage_transactions {

  # calculate totals from csv
  local f_instant_trade_bonus=$(cat ALL_TRANSACTIONS_OVERVIEW.csv | grep ',instant_trade_bonus,' | cut -d, -f7 | awk "{ SUM += \$1} END { printf(\"%.2f\", SUM) }")
  local f_staking_rewards=$(cat ALL_TRANSACTIONS_OVERVIEW.csv | grep ',reward-staking,' | cut -d, -f7 | awk "{ SUM += \$1} END { printf(\"%.2f\", SUM) }")
  local f_giveaway=$(cat ALL_TRANSACTIONS_OVERVIEW.csv | grep ',giveaway,' | cut -d, -f7 | awk "{ SUM += \$1} END { printf(\"%.2f\", SUM) }")
 
 
  #echo -e "\n\n========== Total Results ===========" 
  #echo "Trade Result: $f_trade_result EUR" 
  #echo "Staking Result: $f_staking_rewards EUR"
  #echo "Giveaway Result: $f_giveaway EUR"
  #echo -e "Instand Trade Bonus: $f_instant_trade_bonus EUR\n"
  
  # generate and go through list of years and Exchange/Tax-Types
  rm -f ${g_tmp}/tax_summary_*
  local f_tax_year
  cat ALL_TRANSACTIONS_OVERVIEW.csv | cut -d- -f1 | sort -u  | while read f_tax_year
  do
    #echo "========== Tax year $f_tax_year (German Tax Law) =========="
    local f_exchange_tax_type
    cat ALL_TRANSACTIONS_OVERVIEW.csv | grep "^$f_tax_year-" | cut -d, -f  2,13 | sort -u | while read f_exchange_tax_type
    do
      #echo "$f_exchange_tax_type"
      local f_exchange=$(echo $f_exchange_tax_type | cut -d, -f1)
      local f_tax_type=$(echo $f_exchange_tax_type | cut -d, -f2)

      local f_tax=$(cat ALL_TRANSACTIONS_OVERVIEW.csv | grep "^$f_tax_year-" | cut -d, -f  2,13,14  | egrep -v ',,0$' | grep "$f_exchange_tax_type" | cut -d, -f3 | awk "{ SUM += \$1} END { printf(\"%.2f\", SUM) }")
      #echo "$f_exchange_tax_type: $f_tax"

      [ -n "$f_tax_type" ] && echo "$f_tax_type: $f_tax EUR<br>" >>${g_tmp}/tax_summary_$f_exchange-$f_tax_year

      echo "<html>
<head>
  <meta charset='UTF-8'>
  <meta http-equiv='refresh' content='${INTERVAL}'> 
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <link rel='stylesheet' type='text/css' href='/browser.css'>
  <link rel='stylesheet' type='text/css' href='/charts.min.css'>
  <title>Detailed Transactions on $f_exchange from ${f_tax_year} - Created: $(date)</title>
</head>
<body>
  <h1>Detailed Transactions on $f_exchange from ${f_tax_year}</h1>
<h2>Summary</h2>
$(cat ${g_tmp}/tax_summary_$f_exchange-$f_tax_year)
<h2>List of trades</h2>
- Fees included<br>
- EUR values were calculated using the exchange rate at the time of trading<br>
- Fiat rounded to two decimal places. Internally, further decimal places are used in the calculation<br>
<table>
<tr><td>Date</td><td>Type of transaction</td><td>Crypto value</td><td>Fiat value</td><td>Result</td><td>Tax type</td><td>Tax amount</td></tr>
" >TRANSACTIONS_OVERVIEW-${f_exchange}-${f_tax_year}.html.tmp

cat ALL_TRANSACTIONS_OVERVIEW.csv | grep "^${f_tax_year}-" | grep ",${f_exchange}," | awk -F, '
{
    printf "<tr><td>%s</td><td>%s</td><td>%s %s</td><td>%.2f EUR</td><td>", $1, $3, $5, $4, $15
    if ($17 != "") {
        printf "%.2f EUR", $17
    }
    printf "</td><td>%s</td><td>%.2f EUR</td></tr>\n", $13, $14
}' >>TRANSACTIONS_OVERVIEW-${f_exchange}-${f_tax_year}.html.tmp

      echo "</table></body></html>" >>TRANSACTIONS_OVERVIEW-${f_exchange}-${f_tax_year}.html.tmp
      mv TRANSACTIONS_OVERVIEW-${f_exchange}-${f_tax_year}.html.tmp ../TRANSACTIONS_OVERVIEW-${f_exchange}-${f_tax_year}.html
      
      

    done
    #echo ""
  done

}

