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


function f_ccxt {
 
  # debug
  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  # remove old result
  unset f_ccxt_result

  # lower case
  STOCK_EXCHANGE=${STOCK_EXCHANGE,,}

  if [[ -s /dabo/.${STOCK_EXCHANGE}-secrets ]] 
  then
    . /dabo/.${STOCK_EXCHANGE}-secrets
  else
    g_echo_error "No secrets found (/dabo/.${STOCK_EXCHANGE}-secrets) found"
    return 1
  fi
  
  # Initialize exchange in ccxt if not initialized
  mapfile -t f_jobs < <(jobs -l)
  [[ ${f_jobs[*]} != *python3* ]] && unset f_ccxt_initialized

  # Initialize ccxt in python if not initialized
  if [[ -z "$f_ccxt_initialized" ]] 
  then
    g_echo_debug "Initializing ccxt"
    g_python 'import os' || return 1
    g_python 'import sys' || return 1
    #g_python 'sys.path.append("/ccxt/python")' || return 1
    g_python 'import ccxt' || return 1
  fi

  if ! [[ "$f_ccxt_initialized" =~ $STOCK_EXCHANGE ]]
  then
    g_echo_debug "Initializing exchange ${STOCK_EXCHANGE} in ccxt"
    local f_exchange_type="swap"
    [[ -z "$LEVERAGE" ]]  && f_exchange_type="spot"
    g_python "${STOCK_EXCHANGE} = ccxt.${STOCK_EXCHANGE}({'apiKey': '${API_KEY}','secret': '${API_SECRET}','enableRateLimit': True,'options': {'defaultType': '${f_exchange_type}',},})" || return 1
    if [[ $TESTNET = true ]] 
    then
      g_echo_note "ATTENTION: RUNNING IN TESTNET/SIMULATION/MOCK MODE OF EXCHANGE ${STOCK_EXCHANGE}!!!"
      g_python "${STOCK_EXCHANGE}.set_sandbox_mode(True)" || return 1
    fi
    g_python "${STOCK_EXCHANGE}markets=${STOCK_EXCHANGE}.load_markets()" || return 1
    f_ccxt_initialized="${f_ccxt_initialized}${STOCK_EXCHANGE},"
  fi
 
  # send and receive ccxt command in python - on error kill progress
  if ! g_python "$@"
  then
    g_echo_warn "Resetting CCXT!!!"
    g_kill_all_background_jobs "python3 -iuq"
    unset f_ccxt_initialized
    return 1
  fi

  # reference result to python-result
  declare -ng f_ccxt_result=g_python_result

  # Check for json output or empty json output
  unset f_ccxt_json_out
  if ! [[ "$f_ccxt_result" = '[]' ]]  
  then
    [[ $f_ccxt_result =~ ^\[ ]] && [[ $f_ccxt_result =~ \]$ ]] && f_ccxt_json_out=1
    [[ $f_ccxt_result =~ ^\{ ]] && [[ $f_ccxt_result =~ \}$ ]] && f_ccxt_json_out=1
  fi

  if [[ -z "$f_ccxt_json_out" ]] 
  then
    return 1
  else
    # make the output jq-conform if json poutput
    # avoids errors like: "parse error: Invalid numeric literal at"
    if [[ ${#f_ccxt_result} -gt 99999 ]]
    then
      # sed is needed here because bash parameter substitution like in else hangs with 100% cpu usage if the variable is large. Noticed with output about ~2.5M
      f_ccxt_result=$(echo $f_ccxt_result | sed "s/'/\"/g; s/ None/ null/g; s/ True/ true/g; s/ False/ false/g; s/,,/,/g")
      unset g_json
      g_json="Too large!!!"
    else
      f_ccxt_result=${f_ccxt_result//\'/\"}
      f_ccxt_result=${f_ccxt_result// None/ null}
      f_ccxt_result=${f_ccxt_result// True/ true}
      f_ccxt_result=${f_ccxt_result// False/ false}
      f_ccxt_result=${f_ccxt_result//,,/,}
      [[ -n "$f_print_ccxt_result" ]] && echo "CCXT RESULT: $f_ccxt_result"
      g_json < <(echo $f_ccxt_result)
    fi
  fi

  return 0

}

