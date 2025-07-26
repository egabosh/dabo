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


function get_justtrade_csv_transactions {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  if [[ -s justtrade-export.csv ]]  
  then
    cat justtrade-export.csv | sed 's/\"//g' | egrep '^[0-9]' | egrep    ',otc,justtrade,.+Z,EUR,' | awk -F, '{print $4",sell,"$7","$8","$5","$6",JustTrade"}' >JUSTTRADE-sell.csv.tmp
    cat justtrade-export.csv | sed 's/\"//g' | egrep '^[0-9]' | egrep -v ',otc,justtrade,.+Z,EUR,' | awk -F, '{print $4",buy,"$5","$6","$7","$8",JustTrade"}'  >JUSTTRADE-buy.csv.tmp
    cat JUSTTRADE-buy.csv.tmp JUSTTRADE-sell.csv.tmp | sort >TRANSACTIONS-JUSTTRADE.csv
    rm -f JUSTTRADE-buy.csv.tmp JUSTTRADE-sell.csv.tmp
  fi

}

