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



. /dabo/dabo-prep.sh

interval=$1
[ -z "$interval" ] && exit 1
seconds=$2

while true
do
  echo "$$" > "fetching_data_$interval"
  g_echo_note "Next loop"
  # Reload Config
  . ../../dabo-bot.conf
  . ../../dabo-bot.override.conf
  # notify failed downloads
  if [[ $interval = 1h ]]
  then
    cat FAILED_*/* 2>/dev/null | notify.sh -s "Failed downloads"
    mkdir -p REPORTED_FAILED
    mv FAILED_*/* REPORTED_FAILED/ 2>/dev/null
  fi
  # Timestamp
  export f_timestamp=$(g_date_print)
  # get candles and indicators
  get_ohlcv-candles $interval | tee -a "fetching_data_$interval"
  rm "fetching_data_$interval"

  # calculate ranges
  get_range_all $interval
  # calculate fibonacci from ranges
  get_fibonaccis_all $interval

  # ai/lstm based price prediction
  if [[ $interval = 1d ]] || [[ $interval = 1w ]]
  then
    lstm_prediction $interval # | tee -a "fetching_data_$interval"
    #rm -f "fetching_data_$interval"
  fi

  [[ $interval != 1w ]] && get_marketdata_all $interval
  [[ -n $seconds ]] && sleeptime=$(( ( ($seconds - $(TZ=UTC printf "%(%s)T") % $seconds) % $seconds + 2 )))
  #[[ $interval = 4h ]] && sleeptime=??
  if [[ $interval = 1d ]]
  then
    get_m2_indicator
    sleeptime=$(($(TZ=UTC date +%s -d "tomorrow 0:01") - $(date +%s) +2 ))
  fi
  [[ $interval = 1w ]] && sleeptime=$(($(TZ=UTC date +%s -d "next monday 0:01") - $(date +%s) +2 ))
  g_echo_note "Waiting $sleeptime seconds until next run"
  sleep $sleeptime
done

