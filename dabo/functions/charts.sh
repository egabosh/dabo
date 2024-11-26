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


function charts {
  if ! find ../lightweight-charts.standalone.production.js -mtime -1 2>/dev/null | grep -q "lightweight-charts.standalone.production.js"
  then
    g_echo_note "Refreshing lightweight-charts.standalone.production.js from https://unpkg.com/lightweight-charts/dist/lightweight-charts.standalone.production.js"
    wget ${g_wget_opts} -q https://unpkg.com/lightweight-charts/dist/lightweight-charts.standalone.production.js -O ../lightweight-charts.standalone.production.js
    touch ../lightweight-charts.standalone.production.js
  fi
}
