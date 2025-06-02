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



. /dabo/dabo-prep.sh

sleep 1800
while true
do
  >ALL_TRANSACTIONS_OVERVIEW.csv.tmp
  g_echo_note "Next loop"
  get_bitpanda_api_transactions
  get_justtrade_csv_transactions
  get_onetrading_csv_transactions
  get_phemex_csv_transactions
  get_transactions all
  calc_fifo_pnl_output_file="ALL_TRANSACTIONS_OVERVIEW.csv.tmp"
  for transaction_csv in TRANSACTIONS-*.csv
  do
    calc_fifo_pnl "$transaction_csv"
  done
  mv "$calc_fifo_pnl_output_file" ALL_TRANSACTIONS_OVERVIEW.csv
  webpage_transactions
  sleep 86400
done

