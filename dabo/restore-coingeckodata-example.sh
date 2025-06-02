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


mkdir final
ls -1 *.history.csv | while read x
do
  echo $x
  echo 'Date and Time,Price,Price Change,EMA12,EMA26,MACD,EMA9 MACD (Signal),MACD Histogram,MACD Signal,RSI5,RSI14,RSI21,RSI720,RSI60,RSI120,RSI240,RSI420,Price Change 24h,Price Change 7d,Price Change 14d,Price Change 30d' >final/$x
  grep -A99999999 "2023-05-22 06:15" "$x" | grep ',100,100,100,100$' >>final/$x
  egrep "2023.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+,.+" $x | grep -v ,100,100,100,100 | egrep ":00:|:15:|:30:|:45:" | while read line
  do
    date=$(echo $line | cut -d, -f1)
    gecko=$(echo $line | cut -d, -f18,19,20,21)
    #echo "$x: $date $gecko"
    sed -i "s/^\($date,.*\)100,100,100,100$/\1$gecko/" final/$x
  done
done

