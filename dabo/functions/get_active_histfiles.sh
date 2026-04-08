#!/bin/bash

# Copyright (c) 2022-2026 olli
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


#function get_asset_histfiles {
#
#  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
#  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN
#
#  local f_asset f_eco_asset f_marketdata_asset
#
#  get_symbols_ticker
#  for f_asset in "${ASSETS[@]}"
#  do
#    f_asset_histfiles+=( asset-histories/"${f_asset}".history.{[145][dhwmM],15m}.csv )
#  done
#  for f_eco_asset in $ECO_ASSETS
#  do
#    f_asset_histfiles+=( asset-histories/ECONOMY_${f_eco_asset}.history.{[145][dhwmM],15m}.csv )
#  done
#  [[ -s MARKETDATA_ASSETS ]] && for f_marketdata_asset in $(cat MARKETDATA_ASSETS)
#  do
#    f_asset_histfiles+=( asset-histories/MARKETDATA_${f_marketdata_asset}.history.{[145][dhwmM],15m}.csv )
#  done
#}

function get_asset_histfiles {
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_asset f_eco_asset f_marketdata_asset
  local f_file f_suffix

  get_symbols_ticker

  for f_asset in "${ASSETS[@]}" $f_eco_assets $(cat MARKETDATA_ASSETS)
  do
    for f_suffix in 1M 1w 1d 4h 1h 5m 15m
    do
      f_file="asset-histories/${f_asset}.history.${f_suffix}.csv"
      [[ -s "$f_file" ]] && f_asset_histfiles+=( "$f_file" )
    done
  done
}

function get_asset_histfiles_file {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  get_asset_histfiles
  for f_histfile in ${f_asset_histfiles[@]}
  do
    echo $f_histfile
  done >ASSET_HISTFILES.tmp
  mv ASSET_HISTFILES.tmp ASSET_HISTFILES
}


