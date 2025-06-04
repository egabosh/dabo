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


function get_range_all {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_timeframe=$1
  local f_histfile f_symbol f_symbol_in_array

  get_symbols_ticker
  for f_symbol in "${f_symbols_array_trade[@]}"
  do
    f_symbol=${f_symbol%%:*}
    f_symbol=${f_symbol//\/}

    # get current price to reduce the range, save cpu-power and time
    f_symbol_in_array=${f_symbol/ /}

    f_histfile="asset-histories/${f_symbol}.history.$f_timeframe.csv"
    printf '%(%Y-%m-%d %H:%M:%S)T' >"${f_histfile}.range-calculating"
    g_echo_note "Estimating current trading range of $f_histfile"

    if get_range "$f_histfile"
    then
      printf '%(%Y-%m-%d %H:%M:%S)T' >"${f_histfile}.range-calculated"
    fi
    rm -f "${f_histfile}.range-calculating"

  done
}


function get_range {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_hist_file="$1"
  local f_min_signals=2   # Minimum number of additional signals that must be true (X)
  local f_min_range_size=5  # Minimum range size in %

  local f_last_range_high f_last_range_low f_last_candle_size f_threshold f_abs_move f_candle_change

  # Variables for indicator values
  local f_last_ema50 f_last_ema200 f_last_rsi14 f_last_volume f_macd_histogram_signal f_last_range_close

  while IFS=, read -r f_date f_open f_high f_low f_close f_volume f_change f_ath f_ema12 f_ema26 f_ema50 f_ema100 f_ema200 f_ema400 f_ema800 f_rsi5 f_rsi14 f_rsi21 f_macd f_macd_ema9_signal f_macd_histogram f_macd_histogram_signal f_macd_histogram_max f_macd_histogram_strength
  do

    if [[ "$f_hist_file" != *".1w.csv" && "$f_hist_file" != *".1d.csv" ]]
    then
      if g_num_is_higher $f_open $f_close 
      then
        f_high=$f_open
        f_low=$f_close
      else
        f_low=$f_open
        f_high=$f_close
      fi
    fi

    # Initialize range and indicators on first line
    unset f_first
    if [[ -z "$f_last_range_high" ]]
    then
      local f_first=1
      f_last_range_high="$f_high"
      f_last_range_low="$f_low"
    fi

    # Extend range if necessary
    g_num_is_higher $f_high $f_last_range_high && f_last_range_high="$f_high"
    g_num_is_lower $f_low $f_last_range_low && f_last_range_low="$f_low"

    # calc range size
    g_percentage-diff $f_last_range_low $f_last_range_high
    f_range_size_percentage=$g_percentage_diff_result

    g_calc "$f_high - $f_low"
    f_candle_change=${g_calc_result#-}

    # calculate threshold for significant move (2/3 change in candle)
    g_calc "($f_candle_change * 2) / 3"
    f_threshold=$g_calc_result

    # check if range is large enough: f_min_range_size not first move and only start new range if move is big enough
    if g_num_is_higher $f_range_size_percentage $f_min_range_size && [[ -z "$f_first" ]] && g_num_is_higher $f_candle_change $f_threshold
    then

      # Check indicators for significant change
      local f_signals=0
      local f_signals_text=""

      # EMA50 cross
      if g_num_is_higher $f_close $f_ema50 && g_num_is_lower $f_last_range_close $f_last_ema50
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bullish EMA50 Cross"
      elif g_num_is_lower $f_close $f_ema50 && g_num_is_higher $f_last_range_close $f_last_ema50
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bearish EMA50 Cross"
      fi

      # EMA50/EMA100 cross
      if g_num_is_higher $f_ema50 $f_ema100 && g_num_is_lower $f_last_ema50 $f_last_ema100
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bullish EMA50/EMA100 Cross"
      elif g_num_is_lower $f_ema50 $f_ema100 && g_num_is_higher $f_last_ema50 $f_last_ema100
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bearish EMA50/EMA100 Cross"
      fi

      # EMA50/EMA200 cross
      if g_num_is_higher $f_ema50 $f_ema200 && g_num_is_lower $f_last_ema50 $f_last_ema200
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bullish EMA50/EMA200 Cross"
      elif g_num_is_lower $f_ema50 $f_ema200 && g_num_is_higher $f_last_ema50 $f_last_ema200
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bearish EMA50/EMA200 Cross"
      fi

      # EMA100/EMA200 cross
      if g_num_is_higher $f_ema100 $f_ema200 && g_num_is_lower $f_last_ema100 $f_last_ema200
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bullish EMA100/EMA200 Cross"
      elif g_num_is_lower $f_ema100 $f_ema200 && g_num_is_higher $f_last_ema100 $f_last_ema200
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bearish EMA100/EMA200 Cross"
      fi

      # MACD cross
      if [[ $f_macd_histogram_signal = buy ]] || [[ $f_last_macd_histogram_signal = buy ]]
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bullish MACD Cross"
      elif [[ $f_macd_histogram_signal = sell ]] || [[ $f_last_macd_histogram_signal = sell ]]
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Bearish MACD Cross"
      fi
      
      # RSI overbought/oversold
      if g_num_is_higher $f_rsi14 70 && g_num_is_lower $f_last_rsi14 70
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" RSI Overbought"
      elif g_num_is_lower $f_rsi14 30 && g_num_is_higher $f_last_rsi14 30
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" RSI Oversold"
      fi

      # Volume spike
      g_calc "$f_last_volume * 1.2"
      f_volume_spike_threshold_min=$g_calc_result
      g_calc "$f_last_volume * 1.5"
      f_volume_spike_threshold_max=$g_calc_result
      if g_num_is_higher $f_volume $f_volume_spike_threshold_min && g_num_is_lower $f_volume $f_volume_spike_threshold_max
      then
        f_signals=$((f_signals+1))
        f_signals_text+=" Volume Spike"
      fi

      # DEBUG
      #[[ -n "$f_signals_text" ]] && echo "$f_date $f_signals_text"

      # Only start new range if at least $f_min_signals signals are present
      if [ $f_signals -ge $f_min_signals ]
      then
        g_echo_note "Current range: $f_last_range_low - $f_last_range_high, size: $f_range_size_percentage%"
        printf -v f_rdate '%(%Y-%m-%d %H:%M:%S)T'
        echo "$f_rdate,$f_last_range_low,$f_last_range_high,$f_range_size_percentage" >>${f_hist_file}.range
        echo "$f_last_range_low $f_last_range_high" >${f_hist_file}.range.chart
       
        # DEBUG
        #echo "  Signals ($f_signals):$f_signals_text"
        break
      fi
      
    fi

    # Update indicator values for next iteration
    f_last_range_close=$f_close
    f_last_ema50=$f_ema50
    f_last_ema100=$f_ema100
    f_last_ema200=$f_ema200
    f_last_rsi14=$f_rsi14
    f_last_volume=$f_volume
    f_last_macd_histogram_signal=$f_macd_histogram_signal

  done < <(tac "$f_hist_file")
}


