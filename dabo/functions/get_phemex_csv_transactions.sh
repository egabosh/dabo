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


function get_phemex_csv_transactions {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  # PHEMEX Export format: 
  # Time (UTC),Symbol,Exec Type,Exec. Size,Direction,Exec. Price,Order Size,Order Price,Exec Value,Fee Rate,Fee Paid,Type,"ID"

  # fix for spaces in assets like u1000BONKUSDT -> "1000 BONK"
  sed -i '/,u/ s/ \([^ ]* [^ ]*\)/\1/g' phemex-export.csv

  if [[ -s phemex-export.csv ]]  
  then
    # explicit long
    cat phemex-export.csv | egrep '^[0-9].+,Trade,.+ Long,' | sort | sed 's/,Long,/,Open Long,/; s/Open Long/leverage-buy/; s/Close Long/leverage-sell/; s/ /,/g' | awk -F, '{print $1" "$2","$7","$6","$5","$13","$12",phemex,"$16","$15","$18}' >TRANSACTIONS-phemex-LONG.csv.tmp
    # explicit short
    cat phemex-export.csv | egrep '^[0-9].+,Trade,.+ Short,' | sort | sed 's/,Short,/,Open Short,/; s/Open Short/leverage-sell/; s/Close Short/leverage-buy/; s/ /,/g' | awk -F, '{print $1" "$2","$7","$6","$5","$13","$12",phemex,"$16","$15","$18}' >TRANSACTIONS-phemex-SHORT.csv.tmp
    # buy/sell
    cat phemex-export.csv | egrep '^[0-9].+,Trade,.+,Short,|^[0-9].+,Trade,.+,Long,' | sort | sed 's/Short/leverage-sell/; s/Long/leverage-buy/; s/ /,/g' | awk -F, '{print $1" "$2","$7","$6","$5","$13","$12",phemex,"$16","$15","$18}' >TRANSACTIONS-phemex.csv.tmp
    # liquidations long
    cat phemex-export.csv | egrep '^[0-9].+,Liquidation,.+Long,' | sort | sed 's/ /,/g' | awk -F, '{print $1" "$2",liquidation,"$6","$5","$14","$13",phemex,"$17","$16","$19}' >TRANSACTIONS-phemex-liquidations-LONG.csv.tmp
    # liquidations short
    cat phemex-export.csv | egrep '^[0-9].+,Liquidation,.+Short,' | sort | sed 's/ /,/g' | awk -F, '{print $1" "$2",liquidation,"$6","$5","$14","$13",phemex,"$17","$16","$19}' >TRANSACTIONS-phemex-liquidations-SHORT.csv.tmp
    # fundingfees seeem to be included in sell
    cat TRANSACTIONS-phemex/*.csv  | egrep 'funding' | sort -u >>TRANSACTIONS-phemex.csv.tmp
      
    # put together
    local f_line f_id
    touch "TRANSACTIONS-phemex.csv"
    
    cat TRANSACTIONS-phemex-LONG.csv.tmp TRANSACTIONS-phemex.csv.tmp TRANSACTIONS-phemex-liquidations-LONG.csv.tmp | sort | while read f_line
    do
      f_id=$(echo "$f_line" | cut -d, -f10)
      grep -q "$f_id" "TRANSACTIONS-phemex.csv" || echo $f_line >>"TRANSACTIONS-phemex.csv"
    done

    cat TRANSACTIONS-phemex-SHORT.csv.tmp TRANSACTIONS-phemex-liquidations-SHORT.csv.tmp | sort | while read f_line
    do
      f_id=$(echo "$f_line" | cut -d, -f10)
      grep -q "$f_id" "TRANSACTIONS-phemex.csv" || echo $f_line >>"TRANSACTIONS-phemex.csv"
    done

    # cleanup
    rm -f TRANSACTIONS-phemex-LONG.csv.tmp TRANSACTIONS-phemex-SHORT.csv.tmp TRANSACTIONS-phemex.csv.tmp TRANSACTIONS-phemex-liquidations-LONG.csv.tmp TRANSACTIONS-phemex-liquidations-SHORT.csv.tmp
  fi
}

