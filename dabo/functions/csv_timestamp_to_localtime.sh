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

function csv_timestamp_to_localtime {

  local f_timestamp f_other f_seconds f_time 

  local f_timeformat=$2
  [[ -z $f_timeformat ]] && f_timeformat="%Y-%m-%d %H:%M:00"

  # Read input file line by line
  while IFS= read -r line; do
    # Split line into fields
    IFS=',' read -ra fields <<< "$line"
    
    # Check first field format (must be numeric and 13 digits)
    local f_timestamp="${fields[0]}"
    local f_other="${line#*,}"
    
    if [[ "$f_timestamp" =~ ^[0-9]{13}$ ]]; then
      # Convert milliseconds to seconds for date conversion
      local f_seconds=$((f_timestamp / 1000))
      
      # Use printf to format date (GNU date format specifiers)
      local f_time=$(printf "%(${f_timeformat})T\n" "$f_seconds")
      
      # Reconstruct line with new timestamp
      echo "$f_time,$f_other"
    else
      # Keep line unchanged if timestamp already converted
      echo "$line"
    fi
  done < "$1" > "$g_tmp/tmp.csv"
  
  # Replace original file with processed content
  mv "$g_tmp/tmp.csv" "$1"
}
