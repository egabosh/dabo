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

  local rawhistfile=$1

  echo "$rawhistfile"

  cat "$rawhistfile" | while read f_line
  do
      local time=""
      local timebefore=""
 
      local price30before=""
      local price14before=""
      local price7before=""
      local price1before=""

      local change30before=""
      local change14before=""
      local change7before=""
      local change1before=""
          

      local time=$(echo ${f_line} | cut -d, -f1)

      if echo $f_line | egrep -q "100,100,100,100$"
      then 
        local time=$(echo ${f_line} | cut -d, -f1)
      else 
        continue
      fi

      timebefore=$(date "+%Y-%m-%d %H:%M"  -d "$time 30 day ago")
      #grep "^$timebefore" "$rawhistfile"
      #echo "$f_line"
      price30before=$(grep "^$timebefore" "$rawhistfile" | cut -d, -f2)
      [ -z "$price30before" ] && continue
      local price=$(echo ${f_line} | cut -d, -f2)
      g_percentage-diff $price30before $price
      change30before=${g_percentage_diff_result}
      #echo "XXXXXXX  g_percentage-diff $price30before $price -> $change30before "
   

      timebefore=$(date "+%Y-%m-%d %H:%M"  -d "$time 14 day ago")
      price14before=$(grep "^$timebefore" "$rawhistfile" | cut -d, -f2)
      [ -z "$price14before" ] && continue
      g_percentage-diff $price14before $price
      change14before=${g_percentage_diff_result}

      timebefore=$(date "+%Y-%m-%d %H:%M"  -d "$time 7 day ago")
      price7before=$(grep "^$timebefore" "$rawhistfile" | cut -d, -f2)
      [ -z "$price7before" ] && continue
      g_percentage-diff $price7before $price
      change7before=${g_percentage_diff_result}

      timebefore=$(date "+%Y-%m-%d %H:%M"  -d "$time 1 day ago")
      price1before=$(grep "^$timebefore" "$rawhistfile" | cut -d, -f2)
      [ -z "$price1before" ] && continue
      g_percentage-diff $price1before $price
      change1before=${g_percentage_diff_result}

      #echo "$f_line -- $change1before,$change7before,$change14before,$change30before"

      echo "$f_line" | sed "s/^\(${time}.*\)100,100,100,100/\1$change1before,$change7before,$change14before,$change30before/"
      sed -i "s/^\(${time}.*\)100,100,100,100/\1$change1before,$change7before,$change14before,$change30before/" $rawhistfile

   done

}


find data/botdata/asset-histories -name "*.history.csv" | while read rawhistfile
do
  
  get_asset "${rawhistfile}" || exit 1

done

