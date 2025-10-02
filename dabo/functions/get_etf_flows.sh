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

# get in- and outflows of the US crypto etfs

function get_etf_flows {
  
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_asset f_url line month_num d1 d2 d3 f1 f2 f3 f4

  for f_asset in ${ASSETS[@]}
  do
    
    f_url=""
    [[ $f_asset = "BTC${CURRENCY}" ]] && f_url="https://farside.co.uk/bitcoin-etf-flow-all-data/"
    [[ $f_asset = "ETH${CURRENCY}" ]] && f_url="https://farside.co.uk/ethereum-etf-flow-all-data/"  
    [[ -z "$f_url" ]] && continue  

    g_wget -q "$f_url" -O - | html2markdown --ignore-links --ignore-emphasis --ignore-mailto-links  > "asset-histories/${f_asset}_etf_flows_raw"
  
    while IFS= read -r line
    do
      if [[ $line =~ ^[0-9][0-9]\ [A-Z][a-z]{2}\  ]] && [[ ! $line =~ 0\.0[[:space:]]*$ ]]; then
        line="${line//,/}"
        line="${line// \| /,}"
        line="${line//-/0}"
        line="${line//)/}"
        line="${line//\(/-}"
        line="${line//0.0/0}"
        read -r d1 d2 d3 rest <<< "$line"
        IFS=, read -r f1 f2 f3 f4 rest <<< "$line"

        case "$d2" in
          Jan) month_num=01 ;;
          Feb) month_num=02 ;;
          Mar) month_num=03 ;;
          Apr) month_num=04 ;;
          May) month_num=05 ;;
          Jun) month_num=06 ;;
          Jul) month_num=07 ;;
          Aug) month_num=08 ;;
          Sep) month_num=09 ;;
          Oct) month_num=10 ;;
          Nov) month_num=11 ;;
          Dec) month_num=12 ;;
          *) echo "??" ;;
        esac

        echo "${d3%%,*}-$month_num-$d1,$f2,${line##*,}"
      fi
    done < "asset-histories/${f_asset}_etf_flows_raw" >"asset-histories/${f_asset}_etf_flows_new"

    egrep -h ^[0-9][0-9][0-9][0-9]-[0-9][0-9] "asset-histories/${f_asset}_etf_flows_new" "asset-histories/${f_asset}_etf_flows" | sort -k1,1 -t, -u >"asset-histories/${f_asset}_etf_flows_tmp" 
    mv "asset-histories/${f_asset}_etf_flows_tmp" "asset-histories/${f_asset}_etf_flows"

  done

}

