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



. /etc/bash/gaboshlib.include

g_lockfile

for bashfunc in $(find dabo/functions -type f -name "*.sh")
do
  . "$bashfunc"
done


function get_asset {

  local f_ASSET_HIST_FILE=$1
  local rawhistfile=$2

  echo "$rawhistfile - $f_ASSET_HIST_FILE"

  #cat "$rawhistfile" | egrep ":00:|:15:|:30:|:45:" | while read f_line
  cat "$rawhistfile" | egrep " 14:00:" | while read f_line
  do

      ######## FROM get_asset.sh ########

      [ -s "${f_ASSET_HIST_FILE}" ] || echo "${csv_headline}" >"${f_ASSET_HIST_FILE}"
      # date and price
      echo -n "${f_line}" >>${f_ASSET_HIST_FILE}

      # calculate price change percentage    
      local f_last_price=$(tail -n2 ${f_ASSET_HIST_FILE} | head -n1 | cut -d, -f2)
      if echo $f_last_price | grep -q "^[0-9]"
      then
        local f_price=$(tail -n1 ${f_ASSET_HIST_FILE} | cut -d, -f2)
        g_percentage-diff ${f_last_price} ${f_price}
        local f_price_change=${g_percentage_diff_result}
      else
        local f_price_change=""
      fi
      echo -n ",${f_price_change}" >>"${f_ASSET_HIST_FILE}"

      # calculate macd and rsi
      get_macd_indicator ${f_ASSET_HIST_FILE}
      get_rsi_indicator ${f_ASSET_HIST_FILE} 5
      get_rsi_indicator ${f_ASSET_HIST_FILE} 14
      get_rsi_indicator ${f_ASSET_HIST_FILE} 21
      get_rsi_indicator ${f_ASSET_HIST_FILE} 720
      get_rsi_indicator ${f_ASSET_HIST_FILE} 60
      get_rsi_indicator ${f_ASSET_HIST_FILE} 120
      get_rsi_indicator ${f_ASSET_HIST_FILE} 240
      get_rsi_indicator ${f_ASSET_HIST_FILE} 480

      # get coingecko price change
      f_asset=$(echo ${f_ASSET} | sed "s/${CURRENCY}\$//" | tr '[:upper:]' '[:lower:]')
      echo -n ,100 >>${f_ASSET_HIST_FILE}
      echo -n ,100 >>${f_ASSET_HIST_FILE}
      echo -n ,100 >>${f_ASSET_HIST_FILE}
      echo -n ,100 >>${f_ASSET_HIST_FILE}

      # end with newline
      echo "" >>${f_ASSET_HIST_FILE}

   done

}



export csv_headline="Date and Time,Price,Price Change,EMA12,EMA26,MACD,EMA9 MACD (Signal),MACD Histogram,MACD Signal,RSI5,RSI14,RSI21,RSI720,RSI60,RSI120,RSI240,RSI420,Price Change 24h,Price Change 7d,Price Change 14d,Price Change 30d"

echo -n "parallel -j16 bash -c --" >/tmp/parallel

find home/docker/dabo-binance.ds9.dedyn.io/data/botdata/asset-histories -name "*.history-raw.csv" | while read rawhistfile
do
  
  export f_ASSET_HIST_FILE=$(echo "$rawhistfile" | sed 's/history-raw.csv/history.csv/')
 
  echo -n " \"get_asset ${f_ASSET_HIST_FILE} ${rawhistfile}\" " >>/tmp/parallel

done

export -f get_asset
. /tmp/parallel
