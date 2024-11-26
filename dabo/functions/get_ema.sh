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


function get_ema {

  local f_hist_file="$1"
  local f_hist_file_column="$2"
  local f_period="$3"
  local f_last_ema="$4"
  local f_lastvalue="$5"
  
  f_ema=""
 
  # calculate EMA if last EMA is given
  if [ -n "$f_last_ema" ]
  then
    f_ema=$(echo "scale=10; ${f_lastvalue}*(2/(${f_period}+1))+${f_last_ema}*(1-(2/(${f_period}+1)))" | bc | sed 's/^\./0./; s/^-\./-0./' )
  # calculate SMA12 only for first time as base for EMA and call it EMA if there are enough value periods
  else
    local f_period_sum=$(tail -n${f_period} "${f_hist_file}" | cut -d, -f${f_hist_file_column} | egrep "^[0-9]|-[0-9]" | wc -l)
    if [ ${f_period_sum} -eq ${f_period} ]
    then
      f_ema=$(tail -n ${f_period} "${f_hist_file}" | cut -d"," -f${f_hist_file_column} | awk "{ SUM += \$1} END { printf(\"%10.10f\", SUM/${f_period}) }")
    else
      g_echo_note "${FUNCNAME} $@: Not enough data - waiting for more values. (${f_period} needed; ${f_period_sum} given)"
      return 0
    fi
  fi
}

