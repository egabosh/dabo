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



. /dabo/dabo-prep.sh

while true
do
  g_echo_note "Next loop"
  [[ -s COINMARKETCAPIDS ]] || get_marketdata_coinmarketcap_ids
  sleeptime=$(($(TZ=UTC date +%s -d "next monday 0:00") - $(date +%s) +2 ))
  g_echo_note "Waiting $sleeptime seconds until next run"
  sleep $sleeptime
  get_marketdata_coinmarketcap_ids

done

