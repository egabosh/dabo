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


function get_asset {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
  local f_ASSET="$1"

  # write asset hist file
  local f_ASSET_HIST_FILE="asset-histories/${f_ASSET}.history-raw.csv"

  [[ -f "${f_ASSET_HIST_FILE}" ]]  || echo "Date and Time,Price" >"${f_ASSET_HIST_FILE}"

  #local f_line="${f_timestamp},$(grep "^${f_ASSET}," CCXT_TICKERS | cut -d, -f2)"
  local f_price=$(grep "^${f_ASSET}," CCXT_TICKERS | cut -d, -f2)
  # exponential number (9.881e-05) to normal 
  [[ $f_price =~ ^(-)?(\.)?[0-9]+(\.)?([0-9]+)?(e-[0-9]+)?$ ]] && printf -v f_price -- "%.10f" "$f_price" 
  local f_line="$f_timestamp,$f_price"
  echo "${f_line}" >>${f_ASSET_HIST_FILE}

  local f_linecount=0
  local f_last_price=0
  local f_lines="$(tail -n 51 "${f_ASSET_HIST_FILE}" | wc -l)"
  
  for f_price in $(tail -n 50 "${f_ASSET_HIST_FILE}" | grep "^[0-9]" | cut -d, -f2)
  do
    if [[ "${f_last_price}" == "${f_price}" ]] 
    then
      continue
    fi
    let "f_linecount+=1"
    f_last_price=${f_price}
  done

  if [[ ${f_linecount} -le 3 ]] && [[ ${f_lines} -ge 50 ]] 
  then
    g_echo_note "${f_ASSET_HIST_FILE}: price seems not to change - ignoring"
    return 0
  fi
  
  #[ ${FULL_LOOP} == 0 ] && return 0
  grep -q "^$(echo "${f_timestamp}" | cut -d: -f1,2)" "${f_ASSET_HIST_FILE}" || return 0
  f_ASSET_HIST_FILE="asset-histories/${f_ASSET}.history.csv"
  #if find "${f_ASSET_HIST_FILE}" -mmin -${INTERVAL_MIN} | grep -q "${f_ASSET_HIST_FILE}"
  #then
  #  g_echo_note "${f_ASSET_HIST_FILE} already downloaded in the last ${INTERVAL_MIN} minutes"
  #  return 0
  #fi
 
  # headline
  [[ -s "${f_ASSET_HIST_FILE}" ]]  || echo "${csv_headline}" >"${f_ASSET_HIST_FILE}"
  if [[ -s "${f_ASSET_HIST_FILE}" ]] 
  then
    sed -i -e 1c"$csv_headline" "${f_ASSET_HIST_FILE}"
  else
    echo "$csv_headline" >"${f_ASSET_HIST_FILE}"
  fi

  # date and price
  echo -n "${f_line}" >>${f_ASSET_HIST_FILE}

  # calculate price change percentage
  f_last_price=$(tail -n2 ${f_ASSET_HIST_FILE} | head -n1 | cut -d, -f2)
  if echo $f_last_price | grep -q "^[0-9]"
  then
    f_price=$(tail -n1 ${f_ASSET_HIST_FILE} | cut -d, -f2)
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
  local f_asset=$(echo ${f_ASSET} | sed "s/${CURRENCY}\$//" | tr '[:upper:]' '[:lower:]')
  echo -n ,$(jq -r ".[] |select(.symbol==\"${f_asset}\")|\"\\(.price_change_percentage_24h_in_currency)\"" COINGECKO_GET_ASSETS_CMD_OUT) >>${f_ASSET_HIST_FILE}
  echo -n ,$(jq -r ".[] |select(.symbol==\"${f_asset}\")|\"\\(.price_change_percentage_7d_in_currency)\"" COINGECKO_GET_ASSETS_CMD_OUT) >>${f_ASSET_HIST_FILE}
  echo -n ,$(jq -r ".[] |select(.symbol==\"${f_asset}\")|\"\\(.price_change_percentage_14d_in_currency)\"" COINGECKO_GET_ASSETS_CMD_OUT) >>${f_ASSET_HIST_FILE}
  echo -n ,$(jq -r ".[] |select(.symbol==\"${f_asset}\")|\"\\(.price_change_percentage_30d_in_currency)\"" COINGECKO_GET_ASSETS_CMD_OUT) >>${f_ASSET_HIST_FILE}
  echo -n ,$(jq -r ".[] |select(.symbol==\"${f_asset}\")|\"\\(.price_change_percentage_1y_in_currency)\"" COINGECKO_GET_ASSETS_CMD_OUT) >>${f_ASSET_HIST_FILE}
  echo -n ,$(jq -r ".[] |select(.symbol==\"${f_asset}\")|\"\\(.market_cap_change_percentage_24h)\"" COINGECKO_GET_ASSETS_CMD_OUT) >>${f_ASSET_HIST_FILE}

    # range and fibonacci
  if ! get_range ${f_ASSET_HIST_FILE}
  then
    local f_oldrange=$(tail -n2 ${f_ASSET_HIST_FILE} | head -n1 | cut -d, -f24,25,26,27,28,29,30,31,32,33,34,35)
    #g_echo_note "Taking old range ${f_oldrange}"
    echo -n ",${f_oldrange}" >>$f_ASSET_HIST_FILE
  fi

  # Calculate EMA 50:36 100:37 200:38 800:39
  local f_calcemanumcolumn
  for f_calcemanumcolumn in 50:36 100:37 200:38 800:39
  do
    local f_calcema=$(echo ${f_calcemanumcolumn} | cut -d: -f1)
    local f_caclemacolumn=$(echo ${f_calcemanumcolumn} | cut -d: -f2)
    local f_last_ema="$(tail -n2 "${f_ASSET_HIST_FILE}" | head -n1 | grep "^[0-9]" | cut -d, -f${f_caclemacolumn})"
    if [[ -z "${f_last_ema}" ]] || [[ -z "${f_price}" ]]  
    then
      get_ema "${f_ASSET_HIST_FILE}" 2 ${f_calcema} 
    else
      get_ema "${f_ASSET_HIST_FILE}" 2 ${f_calcema} "${f_last_ema}" "${f_price}"
    fi
    if [[ -z "${f_ema}" ]] 
    then
      echo -n "," >>"${f_ASSET_HIST_FILE}"
    else
      echo -n ",${f_ema}" >>"${f_ASSET_HIST_FILE}"
    fi
  done

  # get coingecko price
  echo -n ,$(jq -r ".[] |select(.symbol==\"${f_asset}\")|\"\\(.current_price)\"" COINGECKO_GET_ASSETS_CMD_OUT) >>${f_ASSET_HIST_FILE}

  # end with newline
  echo "" >>${f_ASSET_HIST_FILE}
}

