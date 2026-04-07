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

g_debug=1

while true
do
  
  for check in $(find /dabo/healthchecks -name "check*.sh" -type f | sort)
  do
    if bash -n "$check"
    then
      g_echo_ok "Running: $check"
      . "$check"
    else
      g_echo_error "Error in $check (check bash -n)"
      continue
    fi
  done
  g_echo_note "Waiting 5min"

  g_healthcheck_rotate
  sleep 300
done

