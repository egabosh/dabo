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



function get_levels_all {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_levelsfile f_level f_symbol f_symbol_in_array t_timeframe f_lines $f_relevant_lines

  get_symbols_ticker
  for f_symbol in "${f_symbols_array_trade[@]}"
  do
    f_symbol=${f_symbol%%:*}
    f_symbol=${f_symbol//\/}

    # get current price to reduce the range, save cpu-power and time
    f_symbol_in_array=${f_symbol/ /}
    f_price=${f_tickers_array[$f_symbol_in_array]}
    
    for f_timeframe in 1w 1d
    do
      
      f_levelsfile="asset-histories/${f_symbol}.history.$f_timeframe.csv"
      printf '%(%Y-%m-%d %H:%M:%S)T' >"${f_levelsfile}.levels-calculating"
      g_echo_note "Estimating relevant levels of $f_levelsfile"

      if get_levels "$f_levelsfile" 
      then
        printf '%(%Y-%m-%d %H:%M:%S)T' >"${f_levelsfile}.levels-calculated"
      else
        continue
      fi

      echo "${f_levels[@]}" >"${f_levelsfile}.levels.new"
      mv "${f_levelsfile}.levels.new" "${f_levelsfile}.levels"

      echo "${f_zones[@]}" >"${f_levelsfile}.zones.new"
      mv "${f_levelsfile}.zones.new" "${f_levelsfile}.zones"

    done

    for f_timeframe in 4h 1h 15m
    do
      f_levelsfile="asset-histories/${f_symbol}.history.$f_timeframe.csv.levels"
      [[ -L $f_levelsfile ]] || ln -s "${f_symbol}.history.1w.csv.levels" $f_levelsfile
    done


  done
}



function get_levels {

  # estimates the relevant levels from price list from array f_prices and put then in array f_levels
  # needs levels csv file with prices in ohlcv

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN
 
  # reset old levels var
  unset f_levels
  unset f_zones

  local f_levelsfile=$1
  if ! [[ -s "$f_levelsfile" ]] 
  then
    g_echo_warn "file $f_levelsfile does not exist or is empty"
    return 1
  fi

  # get number of lines in file and use only half of these numbers as relevant price lines to speed up things - later nearest numbers to the current price
  f_lines=$(wc -l "${f_levelsfile}" | cut -d" " -f1)
  f_relevant_lines=$(( $f_lines * 4 / 5 ))
  [[ $f_relevant_lines -gt 1000 ]]  && f_relevant_lines=1000

  # read high, low and close, sort and use only relevant lines (near current price)
  mapfile -t f_prices < <((cut -d, -f2,3,4,5 "$f_levelsfile" ; echo $f_price) | sed 's/,/\n/g' | sort -rnu | grep -C $f_relevant_lines "^${f_price}$")

  # if there is not enough or no price data
  if [[ -z "${f_prices[100]}" ]] 
  then
    g_echo_note "not enough or no price data"
    return 1
  fi

  local f_min_occurrences i j f_level f_level_count f_level_prices f_level_first_price f_baseprice f_threshold_test

#  # some key points
  local f_lowest_price=${f_prices[-1]}
  local f_highest_price=${f_prices[1]}
  local f_number_of_prices=${#f_prices[@]}
  # calc percentual price range
  g_percentage-diff $f_highest_price $f_lowest_price

  # calc threshold (avarage of percentual price difference)
  local f_price_range_percentage=${g_percentage_diff_result//-/}
#  g_calc "$f_price_range_percentage / $f_number_of_prices * 0.07" || return 1
#  local f_threshold=$g_calc_result
#  # calc threshold in range (1/100 of percentual range)
#  g_calc "$f_threshold * 11 " || return 1
#  local f_threshold_in_range=$g_calc_result

  # how much occurencies / same prices have so show up for a defined level
  local f_min_occurrences=7
  if [[ $f_levelsfile =~ \.1w\. ]] 
  then
    g_calc "$f_price_range_percentage / $f_number_of_prices * 0.07" || return 1
    local f_threshold=$g_calc_result
    g_calc "$f_threshold * 11 " || return 1
    local f_threshold_in_range=$g_calc_result
    #f_threshold="0.0018"
    #f_threshold_in_range="0.18"
    f_min_occurrences=1
  fi
  if [[ $f_levelsfile =~ \.1d\. ]] 
  then
    g_calc "$f_price_range_percentage / $f_number_of_prices * 0.33" || return 1
    local f_threshold=$g_calc_result
    g_calc "$f_threshold * 11 " || return 1
    local f_threshold_in_range=$g_calc_result
    #f_threshold="0.009"
    #f_threshold_in_range="0.09"
    f_min_occurrences=7
  fi
  if [[ $f_levelsfile =~ \.1h\.|\.4h\. ]] 
  then
    #f_threshold="0.03"
    #f_threshold_in_range="0.04"
    f_min_occurrences=9
  fi
  if [[ $f_levelsfile =~ \.15m\.|\.5m\. ]] 
  then
    #f_threshold="0.01"
    #f_threshold_in_range="0.03"
    f_min_occurrences=11
  fi 

  echo "f_threshold_in_range $f_threshold_in_range - f_threshold $f_threshold - f_price_range_percentage $f_price_range_percentage - f_min_occurrences $f_min_occurrences - f_number_of_prices $f_number_of_prices"

  # Loop through the f_prices and compare each number with the next 
  for ((i=0; i<${#f_prices[@]}-1; i++))
  do
    #echo "$i of ${#f_prices[@]}"

    # pair this and next element
    j=$((i+1))
    
    f_threshold_test=$f_threshold
    f_baseprice=${f_prices[i]}
    # if we are in a level use current avarage price of level
    if [[ -n "$f_level_count" ]]  
    then
      #g_calc "($f_level_prices)/$f_level_count"
      #f_baseprice=$g_calc_result
      f_baseprice=$f_level_first_price
      f_threshold_test=$f_threshold_in_range
    fi

    # pair similiar?
    if g_num_is_approx ${f_prices[j]} $f_baseprice $f_threshold_test $f_threshold_test
    then
      # first number of similars?
      if [[ -z "$f_level_count" ]]  
      then
        # new level
        unset f_zone
        f_level_count=2
        f_level_prices="${f_prices[i]}+${f_prices[j]}"
        f_level_first_price=${f_prices[i]}
        f_zone+=("${f_prices[i]}")
        f_zone+=("${f_prices[j]}")
      else
        # add values to level
        f_level_count=$((f_level_count+1))
        f_level_prices="$f_level_prices+${f_prices[j]}"
        f_zone+=("${f_prices[j]}")
      fi
      #echo "level ($f_level_count): $f_level_prices"
    else
      if [[ -n "$f_level_count" ]] 
      then
        # end of level
        #if [[ "$f_level_count" -ge "$f_min_occurrences" ]] 
        if g_num_is_higher_equal $f_level_count $f_min_occurrences
        then
          g_median ${f_zone[@]}
          f_levels+=("$g_median_result")
          f_zones+=("${f_zone[0]},${f_zone[-1]},$f_level_count")
          g_echo_note "adding significant zone at level $g_median_result after reaching $f_level_count times - Zone: ${f_zone[0]} - ${f_zone[-1]}"
          
        fi
        f_level_prices=""
        f_level_count=""
        f_level_first_price=""
      fi
    fi
  done 

}
