#!/bin/bash

# Copyright (c) 2022-2026 ledinis86
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


# ============================================================
# bot-heartbeat.sh - Docker healthcheck for dabo-bot
# ============================================================
# Exit 0 = healthy.
#
# NOTE: this is a standalone healthcheck (run directly), NOT a
# sourced fragment. It is therefore deliberately NOT named
# check-*.sh, because dabo-healthcheck.sh SOURCES every
# dabo/healthchecks/check*.sh fragment; sourcing a file that calls
# "exit" would terminate the healthcheck loop.
#
# Why this is needed:
# 'restart: unless-stopped' only reacts when the container
# EXITS. A hung bot keeps it alive:
# running=true restarts=0 OOMKilled=false
# Docker therefore reports a dead bot as a perfectly healthy
# container. That is exactly what happened in the outage of
# 2026-10-01 (bot silent since ~13:42, container "healthy").
#
# HOW THE CURE WORKS:
# This check kills the bot process. As a result 'tee' gets
# EOF, PID 1 terminates itself, the container EXITS and
# 'restart: unless-stopped' starts it again.
#
# A prerequisite is the fd fix in dabo/dabo-bot.sh (the
# watchdog is started with redirected/closed stdio): without
# it an inherited descriptor keeps the pipe open, 'tee' never
# gets EOF and the container stays up. Deploy both.
#
# PID 1 cannot be signalled from INSIDE the container (kernel
# protection for init in its own PID namespace), so the bot is
# killed, not PID 1.
# ============================================================

BASE="/dabo/htdocs/botdata"
HEARTBEAT="${BASE}/last_full_interval"
MAX_AGE=1200 # 20 min tolerance (INTERVAL=300s, full loop takes ~5 min)
CPU_PROBE=10 # seconds between the two CPU samples

_now() { date +%s; }

# --- 1) find the bot process ---------------------------------
_bot_pid=""
for _p in $(pgrep -f '^/bin/bash /dabo/dabo-bot\.sh' 2>/dev/null); do
  # the main shell is the one with ppid 1
  if [[ "$(awk '{print $4}' /proc/$_p/stat 2>/dev/null)" == "1" ]]; then
    _bot_pid="$_p"; break
  fi
done
if [[ -z "$_bot_pid" ]]; then
  _bot_pid=$(pgrep -f '^/bin/bash /dabo/dabo-bot\.sh' 2>/dev/null | head -1)
fi

if [[ -z "$_bot_pid" ]]; then
  echo "UNHEALTHY: no dabo-bot.sh process found"
  exit 1
fi

# --- 2) check the heartbeat ----------------------------------
if [[ ! -f "$HEARTBEAT" ]]; then
  echo "UNHEALTHY: $HEARTBEAT missing"
  exit 1
fi

_hb=$(( $(_now) - $(stat -c %Y "$HEARTBEAT" 2>/dev/null || echo 0) ))

if (( _hb <= MAX_AGE )); then
  echo "OK: bot $_bot_pid, heartbeat ${_hb}s old (limit ${MAX_AGE}s)"
  exit 0
fi

# --- 3) heartbeat too old: is the bot hung or just busy? -----
# A legitimate full loop burns CPU. A hang does not.
# So take two CPU samples - only act on a standstill.
_cpu() { awk '{print $14+$15}' "/proc/$1/stat" 2>/dev/null || echo 0; }

_c1=$(_cpu "$_bot_pid")
sleep "$CPU_PROBE"
_c2=$(_cpu "$_bot_pid")

if (( _c2 > _c1 )); then
  echo "OK: bot $_bot_pid working (CPU $_c1->$_c2), heartbeat ${_hb}s old is just a slow cycle"
  exit 0
fi

# --- 4) hang confirmed -> kill the bot, Docker restarts it ---
echo "UNHEALTHY: bot $_bot_pid hung (heartbeat ${_hb}s old, CPU $_c1->$_c2 idle) - SIGTERM"
kill -TERM "$_bot_pid" 2>/dev/null
sleep 5
if kill -0 "$_bot_pid" 2>/dev/null; then
  echo "SIGTERM did not work - SIGKILL"
  kill -KILL "$_bot_pid" 2>/dev/null
fi
sleep 2

echo "bot stopped. PID 1 should exit now and 'restart: unless-stopped' will fire."
exit 1
