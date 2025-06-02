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


# functions

BASEPATH=/dabo/htdocs

# load functions
. /etc/bash/gaboshlib.include
for bashfunc in $(find ${BASEPATH}/../functions -type f -name "*.sh")
do
  . "$bashfunc"
done

# vars
LANGUAGE="en_US"
g_tries=13
g_tries_delay=23
g_wget_opts="--timeout 10 --tries=2 --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'"
set +a


# prepare directories
mkdir -p ${BASEPATH}/botdata/asset-histories
cd ${BASEPATH}/botdata

ECO_ASSETS="DXY DOWJONES SP500 NASDAQ MSCIEAFE 10YRTREASURY GOLD MSCIWORLD OILGAS KRE EUR-USD"

. ../../dabo-bot.conf
. ../../dabo-bot.override.conf

# path fpr python/tensorflow
PATH="/python-dabo/bin:$PATH"

