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


function get_bitpanda_api_transactions {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  # Check for Bitpanda API Key - If there get data from Bitpanda API
  if [ -s /dabo/.bitpanda-secrets ]
  then
    source /dabo/.bitpanda-secrets
    g_echo "Bitpanda API-Key found. Getting data from Bitpanda API"
    curl -s -X GET "https://api.bitpanda.com/v1/wallets/transactions?page_size=999999" -H "X-Api-Key: ${BITPANDA_API_KEY}" >BITPANDA_wallets_transactions.csv.tmp \
      && mv BITPANDA_wallets_transactions.csv.tmp BITPANDA_wallets_transactions.json
    curl -s -X GET "https://api.bitpanda.com/v1/fiatwallets/transactions?page_size=999999" -H "X-Api-Key: ${BITPANDA_API_KEY}" >BITPANDA_fiatwallets_transactions.csv.tmp \
      && mv BITPANDA_fiatwallets_transactions.csv.tmp BITPANDA_fiatwallets_transactions.json
    curl -s -X GET "https://api.bitpanda.com/v1/trades?page_size=999999" -H "X-Api-Key: ${BITPANDA_API_KEY}" >BITPANDA_trades.csv.tmp \
      && mv BITPANDA_trades.csv.tmp BITPANDA_trades.json
    unset BITPANDA_API_KEY
    # Trades
    jq -r '
      .data[].attributes |
        select(.status=="finished") |
        select(.type=="sell" or .type=="buy") |
        select(.cryptocoin_symbol!= null) |
        .time.date_iso8601 + "," + .type + "," + .cryptocoin_symbol + "," + .amount + ",EUR," + .amount_eur_incl_fee + ",Bitpanda"
      ' BITPANDA_wallets_transactions.json >BITPANDA.csv.tmp
    # Giveaways
    jq -r '
      .data[].attributes |
        select(.status=="finished") |
        select(.type=="transfer") |
        select(.cryptocoin_symbol!= null) |
        .time.date_iso8601 + "," + .tags[].attributes.short_name + "," + .cryptocoin_symbol + "," + .amount + ",EUR," + .amount_eur_incl_fee + ",Bitpanda"
      ' BITPANDA_wallets_transactions.json | sed 's/,reward,/,giveaway,/' >>BITPANDA.csv.tmp
    # Leverage-Trades 
    jq -r '
      .data[].attributes |
        select(.status=="finished") |
        select(.type=="sell" or .type=="buy") |
        select(.effective_leverage!= null) |
        .time.date_iso8601 + ",leverage-" + .type + "," + .cryptocoin_symbol + "," + .amount_cryptocoin + ",EUR," + .amount_fiat + ",Bitpanda"
      ' BITPANDA_trades.json >>BITPANDA.csv.tmp
     # Workaround for staking-rewards (not availabpe per API yet (https://help.blockpit.io/hc/de-at/articles/360011790820-Wie-importiere-ich-Daten-mittels-Bitpanda-API-Key)
     [ -s bitpanda-export.csv ] && cat bitpanda-export.csv  | grep reward,incoming | awk -F, '{print $2",reward-staking,"$8","$7",EUR,"$5",Bitpanda"}' >>BITPANDA.csv.tmp

     cat BITPANDA.csv.tmp | grep -v ",reward.best," | sort >TRANSACTIONS-BITPANDA.csv
     rm -f BITPANDA.csv.tmp
  fi

}

