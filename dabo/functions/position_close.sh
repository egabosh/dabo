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


function position_close {
  # Info for log
  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_symbol=$1
  local f_position
 
  get_symbols_ticker
  get_positions
  get_position_array

  for f_position in "${f_get_positions_array[@]}"
  do
    get_position_line_vars "$f_position"
    if [[ "$f_symbol" = "$f_position_symbol" ]] 
    then
      f_side="sell"
      [[ "$f_position_side" = "short" ]]  && f_side="buy"
      order $f_symbol crypto_amount:$f_position_contracts $f_side
    fi
  done
}
