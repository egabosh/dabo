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

. /dabo/dabo-prep.sh

WEBCTRL_FILE="/dabo/htdocs/botdata/webcontrol"

while true; do
  g_echo_note "Next run $WEBCTRL_FILE"
  cat "$WEBCTRL_FILE"
  if [[ -s "$WEBCTRL_FILE" ]]
  then
    while IFS= read -r line || [[ -n "$line" ]]
    do
      echo $line
      if [[ "$line" == "order-cancel:ALL" ]]
      then
        g_echo_note "Executing order_cancel_all"
        order_cancel_all
      elif [[ "$line" =~ ^order-cancel:([^:]+):([0-9]+)$ ]]
      then
        SYMBOL="${BASH_REMATCH[1]}"
        ORDER_ID="${BASH_REMATCH[2]}"
        g_echo_note "Executing order_cancel_id $SYMBOL $ORDER_ID true"
        order_cancel_id "$SYMBOL" "$ORDER_ID" true
      elif [[ "$line" =~ ^position-close:([^:]+)$ ]]
      then
        SYMBOL="${BASH_REMATCH[1]}"
        g_echo_note "Executing position_close $SYMBOL"
        position_close "$SYMBOL"
      fi
      sed -i "/^${line}\$/d" "$WEBCTRL_FILE"
    done < "$WEBCTRL_FILE"
  fi
  sleep 1
done

