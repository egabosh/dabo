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


function score {
  [[ -z $s_score ]] && s_score=0
  local f_addscore=${1#+}
  # Numerical guard (2026-11-19): an empty/invalid addend made g_calc return
  # an empty result, which silently wiped the ENTIRE score. Invalid
  # contributions are now ignored, the running score stays unchanged.
  if ! g_num_valid_number "$f_addscore" 2>/dev/null; then
    g_echo_warn "score: ignoring invalid contribution [$f_addscore] ($2) - score unchanged"
    s_score_hist="$s_score_hist
  s_score=$s_score (IGNORED: $1) $2"
    return 0
  fi
  g_calc "$s_score + $f_addscore" || true
  if [[ -z "$g_calc_result" ]] || ! g_num_valid_number "$g_calc_result" 2>/dev/null; then
    g_echo_warn "score: g_calc returned empty/invalid for [$f_addscore] ($2) - score unchanged"
    s_score_hist="$s_score_hist
  s_score=$s_score (CALC-FAIL: $1) $2"
    return 0
  fi
  s_score=$g_calc_result
  s_score_hist="$s_score_hist
  s_score=$s_score ($1) $2"
}

