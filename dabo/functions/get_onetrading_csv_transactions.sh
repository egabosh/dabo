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


function get_onetrading_csv_transactions {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  if [[ -s onetrading-export.csv ]]  
  then

    cat onetrading-export.csv | sed 's/\"//g' | grep ',SELL,' | awk -F, '{print $12","tolower($3)","$6","$5","$8","$9",OneTrading"}' | sort >ONETRADING-sell.csv.tmp

    cat onetrading-export.csv | sed 's/\"//g' | grep ',BUY,' | awk -F, '{print $12","tolower($3)","$11","$9","$8","$5",OneTrading"}' | sort >ONETRADING-buy.csv.tmp

    cat ONETRADING-buy.csv.tmp ONETRADING-sell.csv.tmp | sort >TRANSACTIONS-ONETRADING.csv
    rm -f ONETRADING-buy.csv.tmp ONETRADING-sell.csv.tmp

  fi

}

