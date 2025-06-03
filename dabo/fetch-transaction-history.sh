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

while true
do

  # Run only max once a week
  g_echo_note "Waiting 30 minutes"
  sleep 1800
  if [ -s get_transactions-all-last-run ]
  then
    if find get_transactions-all-last-run -mtime -7 | grep -q get_transactions-all-last-run
    then
      g_echo_note "Waiting for last run older then one week"
      continue
    fi
  else
    g_echo_note "Waiting one week for first run"
    date >get_transactions-all-last-run
    continue
  fi

  >ALL_TRANSACTIONS_OVERVIEW.csv.tmp
  g_echo_note "Next run"
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

  date >get_transactions-all-last-run
done

