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

# Example strategy for managing open positions

##### WARNING! This strategy is only intended as an example and should not be used with real trades!!! Please develop your own strategy ######


# go through trading symbols
for asset in ${ASSETS[@]}
do

  # if no open position remove locked orders and continue with next asset
  [[ -s "orders_locked_${asset}" ]] && if [[ -z "${p[${asset}_liquidation_price]}" ]]
  then
    while read -r orderid
    do
      order_cancel_id $asset $orderid force
    done < "orders_locked_${asset}"
    rm -f "orders_locked_${asset}"
  fi

done

return 0

