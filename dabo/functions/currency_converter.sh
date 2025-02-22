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


function currency_converter {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_currency_amount=$1
  local f_currency=$2
  local f_currency_target=$3
  local f_currency_date=$4
  local f_return

  unset f_currency_converter_result

  # check for cached result
  local f_args=$@
  [ -f CACHE_CURRENCY_CONVERTER ] && f_currency_converter_result=$(egrep "^${f_args}=" CACHE_CURRENCY_CONVERTER | cut -d= -f2)
  [[ -n $f_currency_converter_result ]] && g_num_valid_number "$f_currency_converter_result" && return 0

  local f_line f_rate f_histfile f_date_array f_stablecoin f_reverse f_file f_link_file f_timeframe

  if [[ $f_currency_target =~ ^20.*-.*: ]]
  then
    g_echo_warn "${FUNCNAME} $@: Invalid target"
    g_traceback
    return 1
  fi

  # get current date if none given
  [ -z "$f_currency_date" ] && printf -v f_currency_date '%(%Y-%m-%d %H:%M:%S)T'
 
  # rate per minute
  f_currency_date_minute=$(date -d "${f_currency_date}" "+%Y-%m-%d.%H:%M")

  # hour failback
  f_currency_date_hour=$(date -d "${f_currency_date}" "+%Y-%m-%d.%H")
  
  # day failback
  f_currency_date_day=$(date -d "${f_currency_date}" "+%Y-%m-%d")

  # month failback
  if [ $(date -d "${f_currency_date}" "+%d") = "01" ]
  then
    # on first day in month use month before because no date from current month
    f_currency_date_month=$(date -d "${f_currency_date} yesterday" "+%Y-%m")
  else  
    f_currency_date_month=$(date -d "${f_currency_date}" "+%Y-%m")
  fi

  # path to history files for the converting rate
  [ -d asset-histories ] || mkdir asset-histories
  f_asset_histories="asset-histories/"

  # map USD-Stablecoins to USD
  local f_stablecoins="USDT BUSD"
  for f_stablecoin in $f_stablecoins
  do
    # Link USD Stablecoin files to USD
    cd "$f_asset_histories"
    find . -maxdepth 1 -mindepth 1 -name "*${f_stablecoin}.history.*.csv" | while read f_file
    do
      f_link_file=${f_file/${f_stablecoin}/USD}
      ln -sf "$f_file" "$f_link_file"
    done
    cd - >/dev/null
    # use USD
    if [[ $f_currency_target = $f_stablecoin ]]
    then
      f_currency_target=USD
    fi
    if [[ $f_currency = $f_stablecoin ]] 
    then
      f_currency=USD
    fi
  done
  
  # map EUR-Stablecoins to EUR
  local f_stablecoins="EURC"
  for f_stablecoin in $f_stablecoins
  do
    # Link EUR Stablecoin files to EUR
    cd "$f_asset_histories"
    find . -maxdepth 1 -mindepth 1 -name "*${f_stablecoin}.history.*.csv" | while read f_file
    do
      f_link_file=${f_file/${f_stablecoin}/EUR}
      ln -sf "$f_file" "$f_link_file"
    done
    cd - >/dev/null
    # use USD
    if [[ $f_currency_target = $f_stablecoin ]]
    then
      f_currency_target=EUR
    fi
    if [[ $f_currency = $f_stablecoin ]]
    then
      f_currency=EUR
    fi
  done

  # if there is no currency change (USD USD or USDT USD)
  if [[ $f_currency == $f_currency_target ]]
  then
    f_currency_converter_result=$f_currency_amount
    return 0
  fi
  
  # define possiblefiles
  local f_histfile_default="${f_asset_histories}${f_currency_target}${f_currency}.history"
  local f_histfile_default_reverse="${f_asset_histories}${f_currency}${f_currency_target}.history"

  for f_histfile in "$f_histfile_default" "$f_histfile_default_reverse"
  do
    # search for most precise date
    f_line=$(egrep "^$f_currency_date_minute" "$f_histfile"*m.csv 2>/dev/null | sort | tail -n1)
    [ -z "$f_line" ] && f_line=$(egrep "^$f_currency_date_hour" "$f_histfile"*m.csv 2>/dev/null | sort | tail -n1)
    [ -z "$f_line" ] && f_line=$(egrep "^$f_currency_date_day" "$f_histfile"*h.csv 2>/dev/null | sort | tail -n1)
  done

  # download from coinmarketcap if nothing found
  [ -z "$f_line" ] && for f_histfile in "$f_histfile_default" "$f_histfile_default_reverse" 
  do
    # download data from coinmarketcap
    for f_timeframe in 1d 1w
    do
      [ "${f_currency}" = "USD" ] && get_marketdata_coinmarketcap "${f_currency_target}-${f_currency}" "${f_currency_target}${f_currency}" $f_timeframe
      [ "${f_currency_target}" = "USD" ] && get_marketdata_coinmarketcap "${f_currency}-${f_currency_target}" "${f_currency}${f_currency_target}" $f_timeframe
    done
    f_line=$(egrep "^$f_currency_date_minute" "$f_histfile"*m.csv 2>/dev/null | sort | tail -n1)
    [ -z "$f_line" ] && f_line=$(egrep "^$f_currency_date_hour" "$f_histfile"*m.csv 2>/dev/null | sort | tail -n1)
    [ -z "$f_line" ] && f_line=$(egrep "^$f_currency_date_day" "$f_histfile"*h.csv 2>/dev/null | sort | tail -n1)
    [ -z "$f_line" ] && f_line=$(egrep "^$f_currency_date_month" "$f_histfile"*.csv 2>/dev/null | sort | tail -n1)
    [ -n "$f_line" ] && break
  done  

  # extract rate/price
  [ -n "$f_line" ] && f_rate=$(echo "$f_line" | cut -d, -f2)
  f_reverse=false
  if [ -n "$f_rate" ]
  then
    [[ $f_histfile =~ ${f_currency}${f_currency_target} ]] && f_reverse=true
    [ $f_currency_target = "USD" ] && f_reverse=true
    [ $f_currency = "USD" ] && f_reverse=false
    [ $f_currency_target = "EUR" ] && [ $f_currency = "USD" ] &&  f_reverse=false
    [[ $f_line =~ ^$f_currency_date_hour ]] && break
  fi

  # if no rate found
  if [ -z "$f_rate" ]
  then
    # if EUR source or traget try way over USD as workaround
    if [[ ${f_currency_target} = EUR ]] && [[ $f_currency != USD ]] &&  [[ $f_currency != EUR ]] 
    then
      g_echo_note "trying way over USD (workaround) Target EUR"
      if currency_converter $f_currency_amount $f_currency USD "$f_currency_date"
      then
        currency_converter $f_currency_converter_result USD EUR "$f_currency_date" && f_return=$?
        [[ $f_return == 0 ]] && echo "$@=$f_currency_converter_result" >>CACHE_CURRENCY_CONVERTER
        return $f_return
      fi
    elif [[ ${f_currency_target} != USD ]] && [[ ${f_currency_target} != EUR ]] && [[ $f_currency = EUR ]]
    then
      g_echo_note "trying way over USD (workaround) Source EUR"
      if currency_converter $f_currency_amount EUR USD "$f_currency_date"
      then
        currency_converter $f_currency_converter_result USD ${f_currency_target} "$f_currency_date" && f_return=$?
        [[ $f_return == 0 ]] && echo "$@=$f_currency_converter_result" >>CACHE_CURRENCY_CONVERTER
        return $f_return
      fi
    fi
    # end if no rate found
    g_echo_error "didn't find rate for ${f_currency}-${f_currency_target} - '${FUNCNAME} $@'"
    return 1
  fi
 
  # calculate converted currency and store result
  [[ $f_reverse = true ]] && g_calc "${f_currency_amount}*${f_rate}"
  [[ $f_reverse = false ]] && g_calc "1/${f_rate}*${f_currency_amount}"
  f_currency_converter_result=$g_calc_result

  echo "$@=$f_currency_converter_result" >>CACHE_CURRENCY_CONVERTER

}
