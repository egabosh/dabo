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


function run_strategies {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  local f_strategy

  get_values ${f_symbols_array_trade[*]}
  
  local f_search="*manage*.strategy.sh"
  [[ $1 == full ]] && f_search="*.strategy.sh"
  for f_strategy in $(find /dabo/strategies -type f -name "$f_search" ! -name "\.*" | sort)
  do
    if ! bash -n "${f_strategy}" >$g_tmp/strat_bash_error 2>&1
    then
      g_echo_error "Error in ${f_strategy} $(cat $g_tmp/strat_bash_error)"
      continue
    fi

    unset s_score
    unset s_score_hist
    s_score=0

    g_echo "Running strategy ${f_strategy}"
    . "${f_strategy}" || g_echo_warn "Failed ${f_strategy}"
    g_echo "End strategy ${f_strategy}"
  done

}

