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


function lstm_prediction {
 
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  [[ -z "$DOLSTM" ]]  && return 0

  local marketdata eco_asset f_asset f_latest_date f_line f_datafile
  local f_interval=$1
  local f_datafile="$/aitraindata-$f_interval.csv"
  local f_datafiletmp="${g_tmp}/aitraindata-$f_interval.csv"

  # get/go through symbols
  get_symbols_ticker
  for f_symbol in "${f_symbols_array_trade[@]}"
  do
    f_asset="${f_symbol//:*}"
    f_asset="${f_asset///}"
    f_latest_date=$(tail -n1 asset-histories/$f_asset.history.$f_interval.csv | cut -d, -f1)
    if grep -q "^$f_latest_date," asset-histories/$f_asset.history.$f_interval.lstm_prediction.csv 2>/dev/null
    then
      g_echo_debug "Already done for $f_latest_date $f_asset"
      continue
    fi
 
    f_datafile=asset-histories/$f_asset.history.$f_interval.lstm_prediction.trainingdata.csv
   
    g_echo_debug "Asset: $f_asset"

    # prepare training data
    cut -d, -f 1,$LSTM_USE_FIELDS asset-histories/$f_asset.history.$f_interval.csv  >$f_datafile
    
    if ! [[ $f_asset == BTC$CURRENCY ]]
    then
      awk -F',' 'NR==FNR{a[$1]=$5; next} {print $0 (a[$1] ? "," a[$1] : ",")}' "asset-histories/BTCUSD.history.$f_interval.csv" "$f_datafile" > "$f_datafiletmp"
      mv "$f_datafiletmp" "$f_datafile"
    fi

    for eco_asset in $LSTM_USE_ECO_ASSETS
    do
      if ! [[ -s "asset-histories/ECONOMY-$eco_asset.history.$f_interval.csv" ]] 
      then
        g_echo_warn "${FUNCNAME} $@: File \"asset-histories/ECONOMY-$eco_asset.history.$f_interval.csv\" not found"
        continue
      fi
      awk -F',' 'NR==FNR{a[$1]=$5; next} {print $0 (a[$1] ? "," a[$1] : ",")}' "asset-histories/ECONOMY-$eco_asset.history.$f_interval.csv" "$f_datafile" > "$f_datafiletmp"
      mv "$f_datafiletmp" "$f_datafile"
    done

    for marketdata in $LSTM_USE_MARKETDATA
    do
      marketdata=${marketdata/%_/_$f_asset}
      if ! [[ -s "asset-histories/MARKETDATA_$marketdata.history.$f_interval.csv" ]] 
      then
        g_echo_warn "${FUNCNAME} $@: File \"asset-histories/MARKETDATA_$marketdata.history.$f_interval.csv\" not found"
        continue
      fi
      awk -F',' 'NR==FNR{a[$1]=$5; next} {print $0 (a[$1] ? "," a[$1] : ",")}' "asset-histories/MARKETDATA_$marketdata.history.$f_interval.csv" "$f_datafile" > "$f_datafiletmp"
      mv "$f_datafiletmp" "$f_datafile"
    done

    # remove date/first column
    cut -d',' -f2- $f_datafile > "$f_datafiletmp"
    mv "$f_datafiletmp" "$f_datafile"

    # do lstm training and prediction
    python /dabo/lstm-prediction.py --latest_date "$f_latest_date"  --csv_file "$f_datafile" $LSTM_OPTIONS --csv_output 2>asset-histories/$f_asset.history.$f_interval.lstm_prediction.output | while IFS= read -r f_line
    do
      # Check if the line matches the CSV pattern
      if [[ $f_line =~ [0-9]+(\.[0-9]+)?(,[0-9]+(\.[0-9]+)?){11}$ ]]; then
          # If it matches, append to the CSV file
          echo "$f_line" >> asset-histories/$f_asset.history.$f_interval.lstm_prediction.csv
      else
          # If it doesn't match, print to STDOUT
          echo "$f_line"
      fi
    done >>$f_asset.history.$f_interval.lstm_prediction.output

    #python /dabo/lstm-prediction.py --csv_file "$f_datafile" $LSTM_OPTIONS --csv_output >>asset-histories/$f_asset.history.$f_interval.lstm_prediction.csv 2>$f_asset.history.$f_interval.lstm_prediction.output
  done
 
  return 0

}

