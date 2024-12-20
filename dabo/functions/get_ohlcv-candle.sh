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


function get_ohlcv-candles {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_histfile f_symbol f_timeframe f_1h_histfile f_1d_histfile
  local f_timeframes="1w 1d 4h 1h 15m 5m"
  [ -n $1 ] && f_timeframes=$1

  # fetch economy candles from yahoo finance
  local f_eco_asset
  for f_eco_asset in $ECO_ASSETS
  do
    for f_timeframe in $f_timeframes
    do
      g_echo_note "Fetching/Refreshing $f_eco_asset $f_timeframe"
      f_histfile="asset-histories/ECONOMY-${f_eco_asset}.history.${f_timeframe}.csv"

      # 4h timeframe does not exist on yahoo finance so calc from 1h
      if [ "$f_timeframe" = "4h" ]
      then
        f_1h_histfile="asset-histories/ECONOMY-${f_eco_asset}.history.1h.csv"
        [ -s "$f_1h_histfile" ] && convert_ohlcv_1h_to_4h "$f_1h_histfile" "$f_histfile"
        f_add_missing_ohlcv_intervals "$f_histfile" 4h
      else
        #get_ohlcv-candle "${f_eco_asset}" ${f_timeframe} "${f_histfile}" "ECONOMY-${f_eco_asset}"
        get_marketdata_yahoo DXY ECONOMY-DXY ${f_timeframe}
      fi
      # refresh latest indicators
      [ -s "${f_histfile}" ] && get_indicators "${f_histfile}" 51
    done
  done

  # fetch crypto candles
  get_symbols_ticker
  for f_symbol in BTC/$CURRENCY "${f_symbols_array_trade[@]}"
  do
    # fetch only single symbols (for debugging)
    #[ "$f_symbol" = "BTC/USDT:USDT" ] || continue
    g_echo_note "Fetching/Refreshing $f_symbol $f_timeframe"
    for f_timeframe in $f_timeframes
    do
      f_asset="${f_symbol//:*}"
      f_asset="${f_asset///}"
      f_histfile="asset-histories/$f_asset.history.$f_timeframe.csv"
      #f_histfile_week="asset-histories/$f_asset.history.1w.csv"

      if [ -s "${f_histfile}.indicators-calculating" ]
      then
        g_echo_note "Indicators calculating active on ${f_histfile}"
        continue
      fi 

      # get data
      printf '%(%Y-%m-%d %H:%M:%S)T' >"${f_histfile}.fetching"
      get_ohlcv-candle "$f_symbol" $f_timeframe "${f_histfile}" && printf '%(%Y-%m-%d %H:%M:%S)T' >>"$f_histfile.fetched"

      # refresh latest indicators
      get_indicators "${f_histfile}" 51

      rm -f "${f_histfile}.fetching"

    done

  done
}

function get_ohlcv-candle {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
 
  local f_extdata f_date f_unit_date f_data f_data_array f_data_unit f_open f_high f_low f_close f_volume f_last_unit_date f_last_unit_close
  local f_symbol="$1"
  local f_timeframe=$2
  local f_histfile="$3"
  local f_asset=$4
  unset f_histfile_yahoo f_histfile_coinmarketcap
  #[ -n "$f_asset" ] && f_extdata=1
  #local f_histfile_week="$4"

  # fetch >=1d from coinmarketcap
  if [ "$f_timeframe" = "1d" ] || [ "$f_timeframe" = "1w" ] || [ "$f_timeframe" = "1mo" ] || [ -n "$f_asset" ]
  then
    f_extdata=1
    if [ -z "$f_asset" ]
    then
      f_asset=${f_symbol///}
      f_asset=${f_asset//:*}
    fi

    if [[ $f_asset =~ ^ECONOMY- ]]
    then
      # economy from yahoo finance
      if ! get_marketdata_yahoo "$f_symbol" "$f_asset" $f_timeframe
      then
        g_echo_error "$f_get_marketdata_coinmarketcap_error"
        return 1
      fi
      f_histfile_extdata=$f_histfile_yahoo
    else
      # crypto from coinmarketcap
      if ! get_marketdata_coinmarketcap "$f_symbol" "$f_asset" $f_timeframe
      then
        g_echo_error "$f_get_marketdata_coinmarketcap_error"
        return 1
      fi
      f_histfile_extdata=$f_histfile_coinmarketcap
    fi
  fi 

  # fetch OHLCV data (loop because of multiple chunks on exchanges)
  while true
  do
    # fetch data
    if [ -z "$f_extdata" ]
    then
      # find latest time which is not fetched already create f_since
      get_ohlcv-candle-latest "$f_symbol" "$f_histfile"
      [ -z $f_since ] && break

      # from exchange
      g_echo_note "Get $f_symbol OHLCV-candle $f_timeframe data since $f_since_date"
      f_ccxt "print($STOCK_EXCHANGE.fetchOHLCV(symbol='$f_symbol', timeframe='$f_timeframe', since=$f_since))" || return 1
      # parse the result to array f_data_array
      f_data=${f_ccxt_result//[}
      f_data=${f_data//, /,}
      f_data=${f_data//]]}
      f_data=${f_data//],/+}
      g_array $f_data f_data_ref +
    else
      # from coinmarketcap/yahoo
      
      g_array "$f_histfile_extdata" f_data_ref
    fi
 
    f_data_array=("${f_data_ref[@]}")

    # check if last data already in history file and end if already present
    g_array "${f_data_array[-1]}" f_last_data_unit_ref ,
    [ -z "$f_extdata" ] && printf -v f_last_unit_date '%(%Y-%m-%d %H:%M:%S)T' ${f_last_data_unit_ref[0]::-3}
    [ -n "$f_extdata" ] && f_last_unit_date="${f_last_data_unit_ref[0]}"
    # exit if we have already in the newest date
    [ -s "$f_histfile" ] && grep -q ^"${f_last_unit_date}," "$f_histfile" && break

    

    # go through data and write to history file if new units available
    for f_data_unit in "${f_data_array[@]}"
    do
      
      # use array for each unit and assigned values to vars
      g_array "$f_data_unit" f_data_unit_ref ,
      [ -z "$f_extdata" ] && printf -v f_unit_date '%(%Y-%m-%d %H:%M:%S)T' ${f_data_unit_ref[0]::-3}
      [ -n "$f_extdata" ] && f_unit_date="${f_last_data_unit_ref[0]}"

      # check if date is already in history file
      [ -s "$f_histfile" ] && grep -q ^"$f_unit_date" "$f_histfile" && continue
 
      # define field vars and convert exponential number (for example 9.881e-05) to "normal" notation
      f_open=$f_last_unit_close
      if [ -z "$f_open" ]
      then
        f_open=${f_data_unit_ref[1]}
      fi
      g_num_exponential2normal "$f_open" && f_open=$g_num_exponential2normal_result
      f_high=${f_data_unit_ref[2]}
      g_num_exponential2normal "$f_high" && f_high=$g_num_exponential2normal_result
      f_low=${f_data_unit_ref[3]}
      g_num_exponential2normal "$f_low" && f_low=$g_num_exponential2normal_result
      f_close=${f_data_unit_ref[4]}
      g_num_exponential2normal "$f_close" && f_close=$g_num_exponential2normal_result
      f_last_unit_close=$f_close
      f_volume=${f_data_unit_ref[5]}
      # coinmarketcap historic volume col 6
      [ -n "${f_data_unit_ref[6]}" ] && f_volume=${f_data_unit_ref[6]}
      g_num_exponential2normal "$f_volume" && f_volume=$g_num_exponential2normal_result

      # check date for valid date
      if ! [[ $f_unit_date =~ ^2[0-1][0-9][0-9]-[0-1][0-9]-[0-3][0-9]( [0-2][0-9]:[0-5][0-9]:[0-5][0-9])?$ ]]
      then
        g_echo_warn "Date $f_unit_date \"$f_data_unit\" seems to be invalid @$f_histfile:$f_data_unit"
        break
      fi

      # check vars for valid numbers
      if ! g_num_valid_number "$f_open" "$f_high" "$f_low" "$f_close" "$f_volume"
      then
        g_echo_warn "Data in \"$f_data_unit\" seems to be invalid @$f_histfile:$f_unit_date
        $f_open $f_high $f_low $f_close $f_volume"
        break
      fi
      
      # write history file
      #echo "$f_unit_date,$f_open,$f_high,$f_low,$f_close,$f_volume"
      echo "$f_unit_date,$f_open,$f_high,$f_low,$f_close,$f_volume" >>"$f_histfile"
    
    done

    # end if coinmarketcap (complete file and not time chunks)
    [ -n "$f_extdata" ] && break

    # end if lates refresh is this day
    printf -v f_date '%(%Y-%m-%d)T\n'
    #echo "[ $f_date = $f_since_date ]"
    if [ $f_date = $f_since_date ] 
    then
      break
    fi

  done
}

function get_ohlcv-candle-latest {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_symbol="$1"
  local f_histfile="$2"
  #local f_histfile_week="$3"

  # find latest time which is not fetched already
  [ -s "$f_histfile" ] && local f_last_line=$(tail -n1 "$f_histfile" | grep ^[0-9] | cut -d, -f1,5)
  if [ -n "$f_last_line" ]
  then
    # get latest date from histfile if it exists
    local f_last_line=$(tail -n1 "$f_histfile" | grep ^[0-9] | cut -d, -f1,5)
    f_since=$(date -d "${f_last_line/,*/}" +%s000)
    f_last_unit_close=${f_last_line/*,/}
  else
    # if hist does not exist
    # get week to find the oldest point in time available in exchange
    f_ccxt "print($STOCK_EXCHANGE.fetchOHLCV(symbol='$f_symbol', timeframe='1w'))" || return 0
    # parse oldest point in time from json output
    f_since=${f_ccxt_result//[}
    f_since=${f_since//, /,}
    f_since=${f_since//]*}
    f_since=${f_since//,*}
  fi
  
  # get the date
  printf -v f_since_date '%(%Y-%m-%d)T\n' ${f_since::-3}

}


function convert_ohlcv_1h_to_4h {

    g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

    local f_input_file="$1"
    local f_output_file="$2"

    local f_high=0
    local f_volume=0
    local f_tz f_hour f_lastdate f_currentdate f_latest_date f_go_on f_1h_open f_1h_high f_1h_low f_1h_close f_1h_volume f_date f_open f_low f_close f_4hintervals f_rest
    
    # possibloe 4h intervals
    local f_4hintervals0='^0$|^4$|^8$|^12$|^16$|^20$'
    local f_4hintervals1='^1$|^5$|^9$|^13$|^17$|^21$'
    local f_4hintervals2='^2$|^6$|^10$|^14$|^18$|^22$'
    local f_4hintervals3='^3$|^7$|^11$|^15$|^19$|^23$'

    # check for already converted lines 
    if [ -s "$f_output_file" ] 
    then
      f_latest_date=$(tail -n1 "$f_output_file" | cut -d, -f1)
    else
      f_go_on=1
    fi
 
    # Read the input file line by line
    grep -h "$f_latest_date" -A99999 "$f_input_file" | while IFS=',' read -r f_date f_1h_open f_1h_high f_1h_low f_1h_close f_1h_volume f_rest
    do
        
        # check for already converted lines
        if [[ $f_latest_date = $f_date ]]
        then
          f_go_on=1
          continue
        fi
        [ -z "$f_go_on" ] && continue

        echo "$f_date" 1>&2
  
        f_currentdate="${f_date:0:13}"
        # define intervals by considering local/servers TZ with summer and winter season
        f_hour=${f_date:11:2}
        f_hour=${f_hour#0}
        f_tz=$(date -d "$f_currentdate" +%:z)
        f_tz=${f_tz//:*}
        f_tz=${f_tz#+}
        f_tz=${f_tz#-}
        f_tz=${f_tz#0}
        f_4hintervals=$f_4hintervals0
        [[ $f_tz =~ ^1$|^5$|^9$|^13$ ]] && f_4hintervals=$f_4hintervals1
        [[ $f_tz =~ ^2$|^6$|^10$|^14$ ]] && f_4hintervals=$f_4hintervals2
        [[ $f_tz =~ ^3$|^7$|^11$ ]] && f_4hintervals=$f_4hintervals3

        # is there a new 4h interval
        if [[ $f_hour =~ $f_4hintervals ]]
        then
            # If it's not the first loop, print the previous 4h interval before cleaning the variables
            #if [ -n "$f_lastdate" ]
            if [ -n "$f_open" ]
            then
                echo "${f_lastdate}:00:00,$f_open,$f_high,$f_low,$f_close,$f_volume"
            fi

            # reset the variables for the new 4h interval
            f_low=""
            f_high=0
            f_lastdate=$f_currentdate
            f_volume=0

            # set open for next interval to close from last interval
            f_open=$f_close
        fi

        # set close to 1h close
        f_close=$f_1h_close
        
        # check if the current value is higher or lower than the current high/low
        g_num_is_higher_equal $f_1h_high $f_high && f_high=$f_1h_high
        [ -z "$f_low" ] && f_low=$f_1h_low
        g_num_is_lower_equal $f_1h_low $f_low && f_low=$f_1h_low

        # add volume to the current 4h volume
        g_calc "$f_volume + $f_1h_volume"
        f_volume=$g_calc_result

    done >>"$f_output_file.4htmp"
    egrep -h "^[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-9][0-9].*,[0-9]" "$f_output_file" "$f_output_file.4htmp" | sort -k1,2 -t, -u | sort -k1,1 -t, -u >"$f_output_file.tmp"
    mv "$f_output_file.tmp" "$f_output_file"
    rm -f "$f_output_file.4htmp"
    
}


#function convert_ohlcv_1h_to_1d {
#
#  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"
#
#  local f_input_file="$1"
#  local f_output_file="$2"
#
#  local f_latestdate f_nextdate f_mytimezone f_line f_date f_open f_high f_low f_close f_volume f_inday i
#  
#  if ! [ -s "$f_input_file" ] 
#  then
#    g_echo_error "$f_input_file"
#    return 0
#  fi
#
#  # crypto timezone UTC
#  local f_target_timezone=UTC
#  # US economy timezone America/New_York
#  [[ $f_input_file =~ ECONOMY ]] && f_target_timezone="America/New_York"
# 
#  [ -s "$f_output_file" ] && f_latestdate=$(tail -n1 "$f_output_file" | cut -d, -f1)
#  [ -z "$f_latestdate" ] && f_latestdate=$(date -d "$(head -n1 "$f_input_file" | cut -d, -f1)" +%Y-%m-%d)
#  f_latestdate=$(TZ="$f_target_timezone" date -d "$f_latestdate $f_mytimezone" "+%Y-%m-%d")
#  f_nextdate=$(date -d "$f_latestdate +1day" "+%Y-%m-%d")
#  
#  # mytimezone, respecting summer/winter time
#  f_mytimezone=$(date -d "$_latestdate" +%Z) 
#
#  local f_today=$(TZ="$f_target_timezone" date "+%Y-%m-%d")
#  # check if there is a $f_latestdate
#  grep -A9999 -B24 "^$f_latestdate" "$f_input_file" >"$g_tmp/convert_ohlcv_1h_to_1d_nextlines"
#  if ! [ -s "$g_tmp/convert_ohlcv_1h_to_1d_nextlines" ] 
#  then
#    cat "$f_input_file" >"$g_tmp/convert_ohlcv_1h_to_1d_nextlines"
#    f_nextdate=$(date -d "$(head -n1 "$g_tmp/convert_ohlcv_1h_to_1d_nextlines" | cut -d, -f1)" +%Y-%m-%d)
#  fi
#
#  # go through lines and switch to $f_target_timezone
#  cat "$g_tmp/convert_ohlcv_1h_to_1d_nextlines" | grep ':00:00,' | cut -d, -f1,2,3,4,5,6 | while read f_line
#  do
#    g_array "$f_line" g_line_array ,
#    # calculate day in target timezone
#    g_line_array[0]=$(TZ="$f_target_timezone" date -d "${g_line_array[0]} $f_mytimezone" "+%Y-%m-%d")
#    [[ ${g_line_array[0]} = $f_today ]] && break
#    echo "${g_line_array[0]},${g_line_array[1]},${g_line_array[2]},${g_line_array[3]},${g_line_array[4]},${g_line_array[5]}"
#  done >"${f_output_file}.tmp"
#
#  # check if $f_nextdate really exists in $f_target_timezone if not add a day until it exists
#  # useful for weekends
#  i=1
#  until grep -q "^$f_nextdate" "${f_output_file}.tmp"
#  do
#    #echo $f_nextdate
#    [[ $f_nextdate = $f_today ]] && return 0
#    f_nextdate=$(date -d "$f_nextdate +1day" "+%Y-%m-%d")
#    i=$((i++))
#    if [ $i -gt 10 ]
#    then
#      g_echo_warn "${FUNCNAME} $@: no nextdate found after >10 iterations"
#      return 1
#    fi
#  done
#  
#  # set ent mark to store latest complete day
#  echo END >>"${f_output_file}.tmp"
#
#  # go through converted lines
#  cat "${f_output_file}.tmp" | while read f_line
#  do
#    g_array "$f_line" g_line_array ,
#    [[ ${g_line_array[0]} = $f_today ]] && break
#
#    # wait until next day in target file reached
#    if [[ ${g_line_array[0]} = $f_nextdate ]]
#    then
#      f_end_reached=1
#    else
#      [ -z $f_end_reached ] && continue
#    fi
#
#    # if dayend
#    if [ -n "$f_inday" ] && [[ $f_latestdate != ${g_line_array[0]} ]]
#    then
#      # day end
#      echo "$f_date,$f_open,$f_high,$f_low,$f_close,$f_volume"
#      f_inday=""
#    fi
#    
#    # calc values if inday
#    if [ -n "$f_inday" ]
#    then
#      #echo "in day $f_date" 1>&2
#      # in day
#      # add volume
#      g_calc "$f_volume+${g_line_array[5]}"
#      f_volume=$g_calc_result
#      # look for higher high
#      g_num_is_higher ${g_line_array[2]} $f_high && f_high=${g_line_array[2]}
#      # look for lower low
#      g_num_is_lower ${g_line_array[3]} $f_low && f_low=${g_line_array[3]}
#    fi
#
#    # if newday
#    if [ -z "$f_inday" ]
#    then
#      #echo "day begin ${g_line_array[0]}" 1>&2
#      # day begin
#      f_inday=1
#      f_date=${g_line_array[0]}
#      f_latestdate=$f_date
#      f_open=${g_line_array[1]}
#      f_high=${g_line_array[2]}
#      f_low=${g_line_array[3]}
#      f_close=${g_line_array[4]}
#      f_volume=${g_line_array[5]}
#    fi
#
#  done >>"$f_output_file"
#
#}

function convert_ohlcv_1d_to_1w {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_input_file=$1
  local f_output_file=$2

  local f_week_date f_day f_month f_year f_other f_line f_data
  local -A f_open_prices f_high_prices f_low_prices f_close_prices f_volume_prices
  
  # get lastest date to continue from here and create output file if not exists  
  if [ -s "$f_output_file" ] 
  then
    f_latestdate=$(tail -n1 "$f_output_file" | cut -d, -f1)
  else
   touch "$f_output_file"
  fi
   # if not exists use first date as latest date
  [ -z "$f_latestdate" ] && f_latestdate=$(date -d "$(head -n1 "$f_input_file" | cut -d, -f1)" +%Y-%m-%d)

  # check if there is a $f_latestdate
  grep -A9999 -B9 "^$f_latestdate" "$f_input_file" >"$g_tmp/convert_ohlcv_1d_to_1w_nextlines"
  if ! [ -s "$g_tmp/convert_ohlcv_1d_to_1w_nextlines" ]
  then
    cat "$f_input_file" >"$g_tmp/convert_ohlcv_1d_to_1w_nextlines"
  fi

  # go through lines
  for f_line in $(cat "$g_tmp/convert_ohlcv_1d_to_1w_nextlines")
  do
    IFS=',' read -r f_date f_open f_high f_low f_close f_volume f_other <<< "$f_line"
    IFS='-' read -r f_year f_month f_day <<< "$f_date"

    [ -z "$f_high" ] && f_high=$f_open
    [ -z "$f_low" ] && f_low=$f_open
    [ -z "$f_close" ] && f_close=$f_open
    [ -z "$f_volume" ] && f_volume=0

    # use week-number to sort day data in weeks
    f_week_number=$(date -d "$f_year-$f_month-$f_day" +%U)
    f_week_number=${f_week_number##0}
    f_week_year=$f_year$f_week_number

    # calculate week ohlcv and write to arrays sortet by f_week_year
    g_calc "${f_open_prices[$f_week_year]:-$f_open}"
    f_open_prices[$f_week_year]=$g_calc_result
    
    g_num_is_higher "$f_high" "${f_high_prices[$f_week_year]:-0}" && f_high_prices[$f_week_year]=$f_high
    
    [ -z "${f_low_prices[$f_week_year]}" ] && f_low_prices[$f_week_year]=$f_low
    g_num_is_lower "$f_low" "${f_low_prices[$f_week_year]:-0}" && f_low_prices[$f_week_year]=$f_low

    f_close_prices[$f_week_year]=$f_close
    
    [ -z "$f_volume" ] && f_volume=0
    g_calc "${f_volume_prices[$f_week_year]:-0}+$f_volume"
    f_volume_prices[$f_week_year]=$g_calc_result
  done
  
  # go through array(s) and write down missing week data
  for f_week_year in "${!f_open_prices[@]}"
  do
    f_week_date=$(date -d "${f_week_year:0:4}-01-01 +$((${f_week_year:4})) week -1day" +%F)
    # ignore if date alerady exists
    grep -q ^$f_week_date, "$f_output_file" && continue
    echo "$f_week_date,${f_open_prices[$f_week_year]},${f_high_prices[$f_week_year]},${f_low_prices[$f_week_year]},${f_close_prices[$f_week_year]},${f_volume_prices[$f_week_year]}"
  done | sort >>"$f_output_file"
}



function f_add_missing_ohlcv_intervals {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_histfile="$1"
  local f_interval="$2"
  [[ $f_interval = 5m ]] && f_interval=300
  [[ $f_interval = 15m ]] && f_interval=900
  [[ $f_interval = 1h ]] && f_interval=3600
  [[ $f_interval = 4h ]] && f_interval=14400
  [[ $f_interval = 1d ]] && f_interval=86400

  # get interval from filename if not given
  if [ -z "$f_interval" ]
  then
    [[ $f_histfile =~ \.5m\. ]]  && f_interval=300
    [[ $f_histfile =~ \.15m\. ]]  && f_interval=900
    [[ $f_histfile =~ \.1h\. ]]  && f_interval=3600
    [[ $f_histfile =~ \.4h\. ]]  && f_interval=14400
    [[ $f_histfile =~ \.1d\. ]]  && f_interval=86400
  fi

  # 1w should be complete in every case
  [[ $f_interval = 1w ]] && return 0
  [[ $f_histfile =~ \.1w\. ]] && return 0


  local f_prev_date f_prev_vals f_curr_date f_curr_vals f_missing_date f_open f_high f_low f_close f_volume f_percent f_open f_counter

  # go through csv per line
  while IFS=',' read -r f_curr_date f_open f_high f_low f_close f_volume f_percent f_curr_vals
  do

    #echo "$f_curr_date" 1>&2

    # if prev date is not empty
    if [ -z "$f_prev_date" ]
    then
      f_prev_date=$f_curr_date
      echo "$f_curr_date,$f_open,$f_high,$f_low,$f_close,$f_volume,$f_percent,$f_curr_vals"
      continue
    fi

    #echo "$f_curr_date x" 1>&2

    # only 10 interations to prevelt endless loop
    f_counter=0
    while [ $f_counter -lt 10 ]
    #while true
    do

      ((f_counter++))
      #echo "$f_curr_date xx $f_counter" 1>&2

      # get second timestamps
      f_prev_date_in_seconds=$(date -d"$f_prev_date" +%s)
      f_curr_date_in_seconds=$(date -d"$f_curr_date" +%s)
 
     # echo [ "$f_prev_date_in_seconds" -gt "$f_curr_date_in_seconds" ] # && break

      # calculate/check the next timestamp from previous
      # and check for summer/winter time in 4h or greater interval
      if [ $f_interval -gt 3600 ]
      then 
        # reduce an hour because of possible summer/winter time change
        #g_calc "$f_curr_date_in_seconds - ($f_counter * $f_prev_date_in_seconds - 3600)"
        g_calc "$f_curr_date_in_seconds - $f_prev_date_in_seconds - 3600"
      else
        #g_calc "$f_curr_date_in_seconds - $f_counter * $f_prev_date_in_seconds"
        g_calc "$f_curr_date_in_seconds - $f_prev_date_in_seconds"
      fi
      if [ $g_calc_result -gt $f_interval ]
      then
        # calc missing timestamp in seconds 
        #f_curr_date_in_seconds=$(( f_prev_date_in_seconds + f_interval * f_counter ))
        f_curr_date_in_seconds=$(( f_prev_date_in_seconds + f_interval ))
        # and calculate next timestamp
        g_calc "$f_curr_date_in_seconds - $f_prev_date_in_seconds"

        # change date format if day or week
        if [ $f_interval -lt 86400 ]
        then
          f_missing_date=$(date -d"@$f_curr_date_in_seconds" +"%F %T")
        else
          f_missing_date=$(date -d"@$f_curr_date_in_seconds" +"%F")
        fi
        
        # prevent endless loop if something goes wrong (strange errors in 1d ohlcv!)
        f_missing_date_in_seconds=$(date -d"$f_missing_date" +%s)
        if [ $f_missing_date_in_seconds -lt $f_curr_date_in_seconds ]
        then
          [ -z "$f_curr_vals" ] && echo "$f_curr_date,$f_open,$f_high,$f_low,$f_close,$f_volume,$f_percent"
          [ -n "$f_curr_vals" ] && echo "$f_curr_date,$f_open,$f_high,$f_low,$f_close,$f_volume,$f_percent,$f_curr_vals"
          f_prev_date=$f_curr_date
          break
        fi

        # write missing line
        [ -z "$f_curr_vals" ] && echo "$f_missing_date,$f_open,$f_open,$f_open,$f_open,0,0.00"
        [ -n "$f_curr_vals" ] && echo "$f_missing_date,$f_open,$f_open,$f_open,$f_open,0,0.00,$f_curr_vals"
        f_prev_date=$f_missing_date
      else
        f_prev_date=$f_curr_date
        [ -z "$f_curr_vals" ] && echo "$f_curr_date,$f_open,$f_high,$f_low,$f_close,$f_volume,$f_percent"
        [ -n "$f_curr_vals" ] && echo "$f_curr_date,$f_open,$f_high,$f_low,$f_close,$f_volume,$f_percent,$f_curr_vals"
        break
      fi
      
    done

  done < "$f_histfile" > $g_tmp/f_add_missing_ohlcv_intervals_result

  # replace old file with new if they are different
  if ! cmp --silent "$f_histfile" "$g_tmp/f_add_missing_ohlcv_intervals_result"
  then
    g_echo_note "Replacing $f_histfile"
    #diff "$g_tmp/f_add_missing_ohlcv_intervals_result" "$f_histfile"
    cat "$g_tmp/f_add_missing_ohlcv_intervals_result" >"$f_histfile"
  fi
}
