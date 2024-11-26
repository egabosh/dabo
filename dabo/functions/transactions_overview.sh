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


function transactions_overview {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  get_transactions
  
  get_bitpanda_api_transactions
  get_justtrade_csv_transactions
  get_onetrading_csv_transactions

  >ALL_TRANSACTIONS_OVERVIEW.csv.tmp
  >ALL_TRANSACTIONS_OVERVIEW_WARN.csv.tmp
  >TRANSACTIONS_OVERVIEW-trade-result_tax_german_eur.tmp

  local f_exchange f_asset f_transactions_array f_transaction f_result f_asset_quantity f_asset_quantity_sold f_currency_quantity f_currency_quantity_sold f_currency_spent f_date f_type f_asset_amount f_currency f_currency_amount f_fee_currency f_fee_amount f_sell_result f_taxable f_tax_type f_one_year_ago f_currency_amount_eur f_currency_spent_eur f_currency_quantity_sold_eur f_note f_asset_quantity_remaining f_currency_remaining f_year f_currency_spent_eur_tax f_currency_quantity_sold_eur_tax f_sell_result_percentage f_sell_result_percentage_eur

  f_assets_per_exchange=$(egrep -h -v '^DATE,TYPE,ASSET,ASSET_AMOUNT,CURRENCY,CURRENCY_AMOUNT,EXCHANGE|^#|^$|^ +$' TRANSACTIONS-*.csv | cut -d, -f3,7 | sort -u)

  for f_asset_per_exchange in ${f_assets_per_exchange}
  do
    mapfile -d, -t f_asset_per_exchange_array < <(echo $f_asset_per_exchange)
    f_asset=${f_asset_per_exchange_array[0]}
    f_exchange=${f_asset_per_exchange_array[1]%$'\n'}

    # check values
    [ -z "$f_asset" ] && continue
    [ -z "$f_exchange" ] && continue

    # Ignore stableCoins, EUR, USD
    [[ $f_asset = USDT ]] && continue
    [[ $f_asset = USDC ]] && continue
    [[ $f_asset = BUSD ]] && continue
    [[ $f_asset = USD ]] && continue
    [[ $f_asset = EUR ]] && continue

    echo -e "\n\n=== Asset $f_asset on Exchange $f_exchange"  >>ALL_TRANSACTIONS_OVERVIEW.log
    g_echo_note "transactions_overview: Asset $f_asset on Exchange $f_exchange"

    f_result=0
    f_result_eur=0
    f_asset_quantity=0
    f_asset_quantity_sold=0
    f_currency_quantity=0
    f_currency_quantity_sold=0
    f_currency_quantity_sold_eur=0
    f_asset_quantity_remaining=0
    f_currency_spent=0
    f_currency_spent_eur=0

    mapfile -t f_transactions_array < <(egrep -h -v '^DATE,TYPE,ASSET,ASSET_AMOUNT,CURRENCY,CURRENCY_AMOUNT,EXCHANGE|^#|^$|^ +$' TRANSACTIONS-*.csv | sort -u | egrep ",${f_asset},.+,.+,${f_exchange}" | sort)
    for f_transaction in "${f_transactions_array[@]}"
    do 
      mapfile -d, -t f_transaction_array < <(echo $f_transaction)
      f_date=${f_transaction_array[0]}
      f_type=${f_transaction_array[1]}
      f_asset_amount=${f_transaction_array[3]}
      f_currency=${f_transaction_array[4]}
      if [ -z "$f_currency" ]
      then
        g_echo_warn "f_currency empty: $f_transaction"
        continue
      fi
      f_currency_amount=${f_transaction_array[5]}
      f_currency_amount_eur=0
      f_fee_currency=${f_transaction_array[7]}
      f_fee_amount=""
      [ -n "$f_fee_currency" ] && printf -v f_fee_amount %.20f ${f_transaction_array[8]}
      f_sell_result=0
      f_sell_result_eur=0
      f_taxable=0
      f_tax_type=""
      f_one_year_ago=""
      f_note=""
      f_sell_result_percentage=0
      f_sell_result_percentage_eur=0

      # if there is a fee change to f_currency_amount and deduct f_currency_amount
      if [ -n "$f_fee_amount" ]
      then
        if [[ $f_fee_currency != $f_currency ]]
        then
          #mapfile -dT -t f_date_array < <(echo $f_date)
          #if currency_converter $f_fee_amount $f_fee_currency $f_currency ${f_date_array[0]}
          if currency_converter $f_fee_amount $f_fee_currency $f_currency "$f_date"
          then
            f_fee_amount=$f_currency_converter_result
            f_fee_currency=$f_currency
          else
            #g_echo_warn "!!!!!! Could not convert currency $f_fee_currency to $f_currency"
            echo "$f_date,$f_exchange,$f_type,$f_asset,$f_asset_amount,$f_currency,$f_currency_amount,$f_one_year_ago,$f_currency_spent,$f_asset_quantity,$f_result,$f_sell_result,$f_tax_type,$f_taxable,$f_currency_amount_eur,$f_result_eur,$f_sell_result_eur,$f_asset_quantity_remaining,$f_note,Could not convert currency $f_fee_currency to $f_currency" 1>&2
            continue
          fi
        fi
        # deduct fee
        if [[ $f_type =~ sell ]]
        then
           g_calc "$f_currency_amount-($f_fee_amount)"
           f_currency_amount=$g_calc_result
        elif [[ $f_type =~ fundingfee ]]
        then
           g_calc "$f_currency_spent+($f_fee_amount)"
           f_currency_spent=$g_calc_result
           f_currency_amount=$f_fee_amount
           f_tax_type="Included in purchase price"
        else
           g_calc "$f_currency_amount+($f_fee_amount)"
           f_currency_amount=$g_calc_result
        fi
      fi

      # get f_currency_amount in EUR for german tax declaration
      if [[ $f_currency != EUR ]]
      then
        if currency_converter $f_currency_amount $f_currency EUR "$f_date"
        then
          f_currency_amount_eur=$f_currency_converter_result
        else
          g_echo_error "!!!!!! Could not convert currency $f_currency to EUR"
          return 1
        fi
      else
        f_currency_amount_eur=$f_currency_amount
      fi
      
      # round fiat numbers to 2 decimal places
      local f_fiats="USD USDT BUSD"
      local f_fiat
      for f_fiat in $f_fiats
      do
        [ "$f_fiat" = "$f_currency" ] && printf -v f_currency_amount %.2f $f_currency_amount
      done

      # If transfer to stake -> irrelevant/ignore
      [[ $f_type =~ stake ]] && continue

      # what did I spent on asset in currency
      #if [[ $f_type =~ buy|leverage-buy ]]
      if [[ $f_type =~ buy|leverage-buy|reward-staking|instant_trade_bonus|giveaway ]]
      then
        g_calc "$f_currency_spent+$f_currency_amount"
        f_currency_spent=$g_calc_result

        g_calc "$f_currency_spent_eur+$f_currency_amount_eur"
        f_currency_spent_eur=$g_calc_result
      fi
      printf -v f_currency_amount_eur %.2f $f_currency_amount_eur

      # what did I spent on asset
      if [[ $f_type =~ buy|leverage-buy|reward-staking|instant_trade_bonus|giveaway ]]
      then
        g_calc "$f_asset_quantity+$f_asset_amount"
        f_asset_quantity=$g_calc_result
        g_calc "$f_asset_quantity_remaining+$f_asset_amount"
        f_asset_quantity_remaining=$g_calc_result
      fi
      

      # rise result if reward-staking|instant_trade_bonus|giveaway
      if [[ $f_type =~ reward-staking|instant_trade_bonus|giveaway ]]
      then
        if [[ $f_type =~ reward-staking ]]
        then
          f_taxable=$f_currency_amount_eur
          f_tax_type="Staking Reward (Einkommenssteuersatz)"
        fi
        if [[ $f_type =~ instant_trade_bonus ]]
        then
          f_taxable=$f_currency_amount_eur
          f_tax_type="Instand Trade Bonus (Einkommenssteuersatz)"
        fi
        if [[ $f_type =~ giveaway ]]
        then
          f_taxable=$f_currency_amount_eur
          f_tax_type="Giveaway (Einkommenssteuersatz)"
        fi

      fi

      # calculate result and tax (if taxable) on sale
      if [[ $f_type =~ sell ]]
      then

        ## Some validity checks
        # not for leverage because of short-trade
        if [ $f_type = sell ]
        then
          # if sell on never buyed!?
          if [ $f_currency_spent = 0 ]
          then
            #g_echo_warn "!!!!!! Sell never buyed!? Spent currency on $f_asset is 0"
            echo "$f_date,$f_exchange,$f_type,$f_asset,$f_asset_amount,$f_currency,$f_currency_amount,$f_one_year_ago,$f_currency_spent,$f_asset_quantity,$f_result,$f_sell_result,$f_tax_type,$f_taxable,$f_currency_amount_eur,$f_result_eur,$f_sell_result_eur,$f_asset_quantity_remaining,$f_note,Sell never buyed!? Spent currency on $f_asset is 0" 1>&2
            continue
          fi
          # if sell wahats not exists!?
          if [ $f_asset_quantity = 0 ]
          then
            #g_echo_warn "!!!!!! Sell never buyed!? Buyed asset $f_asset is 0"
            echo "$f_date,$f_exchange,$f_type,$f_asset,$f_asset_amount,$f_currency,$f_currency_amount,$f_one_year_ago,$f_currency_spent,$f_asset_quantity,$f_result,$f_sell_result,$f_tax_type,$f_taxable,$f_currency_amount_eur,$f_result_eur,$f_sell_result_eur,$f_asset_quantity_remaining,$f_note,Sell never buyed!? Buyed asset $f_asset is 0" 1>&2
            continue
          fi
        fi

        # summarize sold asset quantity
        g_calc "$f_asset_quantity_sold+$f_asset_amount"
        f_asset_quantity_sold=$g_calc_result
       
        # remaining quantity after sell
        g_calc "$f_asset_quantity-$f_asset_quantity_sold"
        f_asset_quantity_remaining=$g_calc_result

        # summarize sold currency quantity
        g_calc "$f_currency_quantity_sold+$f_currency_amount"
        f_currency_quantity_sold=$g_calc_result

        # summarize sold currency quantity in EUR
        g_calc "$f_currency_quantity_sold_eur+$f_currency_amount_eur"
        f_currency_quantity_sold_eur=$g_calc_result

        ## Check for ended trade (asset-quantity=0 or tttt)
        # if all is sold trade ended and calculate PNL
        local f_trade_end=0
        local f_dust=0
        local f_dust_eur=0
        g_calc "$f_asset_quantity_sold==$f_asset_quantity"
        [ ${g_calc_result} -eq 1 ] && f_trade_end=1
 
        # Alterntively check for remaining dust only to find end of trade and calculate PNL
        if [ ${g_calc_result} -eq 0 ]
        then
          currency_converter $f_asset_quantity_remaining $f_asset $f_currency "${f_date}" || g_echo_warn "Error converting currency"
          f_currency_remaining=$f_currency_converter_result
          if g_num_is_between $f_currency_remaining -5 5
          then
            f_dust=$f_currency_remaining
            currency_converter $f_asset_quantity_remaining $f_asset EUR "${f_date}" || g_echo_warn "Error converting currency to EUR"
            f_dust_eur=$f_currency_converter_result
            g_echo_note "Quantity ($f_asset_quantity $f_asset - $f_dust (USD) looks like dust - Ending trade" >>ALL_TRANSACTIONS_OVERVIEW.log
            f_note="$f_asset_quantity $f_asset - $f_dust (USD) looks like dust - Ending trade"

            f_trade_end=1

            # add to sold quantity
            g_calc "$f_currency_quantity_sold+($f_dust)"
            f_currency_quantity_sold=$g_calc_result
            # add to sold quantity EUR
            g_calc "$f_currency_quantity_sold_eur+($f_dust_eur)"
            f_currency_quantity_sold_eur=$g_calc_result

            # correct positions
            f_currency_amount=$f_currency_quantity_sold
            f_currency_amount_eur=$f_currency_quantity_sold_eur
            f_asset_amount=$f_asset_quantity
          
          else
            g_echo_note "Tade not closed - partial sale!? Remaining $f_asset_quantity_remaining $f_asset ($f_currency_remaining $f_currency)!?" >>ALL_TRANSACTIONS_OVERVIEW.log
            f_note="Trade not closed - partial sale. Remaining $f_asset_quantity_remaining $f_asset ($f_currency_remaining $f_currency)"
          fi
        fi

        if [ ${f_trade_end} -eq 1 ]
        then

          echo "Buy price: $f_currency_spent $f_currency ($f_currency_spent_eur EUR)" >>ALL_TRANSACTIONS_OVERVIEW.log
          echo "Sell price: $f_currency_quantity_sold $f_currency ($f_currency_quantity_sold_eur EUR)" >>ALL_TRANSACTIONS_OVERVIEW.log
          
          # calculate result of trade 
          g_calc "$f_currency_quantity_sold-$f_currency_spent"
          f_sell_result=$g_calc_result
          g_calc "$f_currency_quantity_sold_eur-$f_currency_spent_eur"
          f_sell_result_eur=$g_calc_result
          echo "Sell result: $f_sell_result $f_currency ($f_sell_result_eur EUR)" >>ALL_TRANSACTIONS_OVERVIEW.log

          g_percentage-diff $f_currency_spent $f_currency_quantity_sold
          f_sell_result_percentage=$g_percentage_diff_result
          g_percentage-diff $f_currency_spent_eur $f_currency_quantity_sold_eur
          f_sell_result_percentage_eur=$g_percentage_diff_result
          echo "Sell result percentage: ${f_sell_result_percentage}% (EUR ${f_sell_result_percentage_eur}%)" >>ALL_TRANSACTIONS_OVERVIEW.log

          # calculate complete result
          g_calc "$f_result+($f_sell_result)"
          f_result=$g_calc_result

          # calculate complete result EUR
          g_calc "$f_result_eur+($f_sell_result_eur)"
          f_result_eur=$g_calc_result
   
          # reset vars
          f_asset_quantity=0
          f_asset_quantity_sold=0
          f_asset_quantity_remaining=0
          f_currency_spent=0
          printf -v f_currency_spent_eur_tax %.2f $f_currency_spent_eur
          f_currency_spent_eur=0
          f_currency_quantity_sold=0
          printf -v f_currency_quantity_sold_eur_tax %.2f $f_currency_quantity_sold_eur
          f_currency_quantity_sold_eur=0
        fi

        # at leverage always full taxable
        if [ "$f_type" = "leverage-sell" ] && [ ${f_trade_end} -eq 1 ]
        then
          f_taxable=$f_sell_result
          f_tax_type="Verkauf gehebelter Position (Kapitalertragssteuer)"
        # at no leverage-sell
        elif [ ${f_trade_end} -eq 1 ]
        then
          ## taxable - one year?
          f_seconds_sell_ago=$(date -d "$f_date 1 year ago" +%s)

          oldIFS=$IFS
          IFS=$'\n'
          ## catculate f_asset_amount_tax_able and/or f_asset_amount_tax_free for current history
          f_asset_amount_tax_able=0
          f_asset_amount_tax_free=0
          mapfile -t f_assetlines_array < <(egrep ",$f_exchange,[a-z]+,$f_asset," ALL_TRANSACTIONS_OVERVIEW.csv.tmp)
          for f_assetline in "${f_assetlines_array[@]}"
          do
            mapfile -d, -t f_assetline_array < <(echo $f_assetline)
            f_assetline_date=${f_assetline_array[0]}
            f_assetline_type=${f_assetline_array[2]}
            f_assetline_amount=${f_assetline_array[4]}
            f_seconds_transfer_ago=$(date -d "$f_assetline_date" +%s)
            if [[ $f_assetline_type =~ buy|reward-staking|instant_trade_bonus|giveaway ]]
            then
              if [ $f_seconds_sell_ago -gt $f_seconds_transfer_ago ]
              then
                # buy from sell one year ago
                g_calc "$f_asset_amount_tax_free+$f_assetline_amount"
                f_asset_amount_tax_free=$g_calc_result
              else
                # buy from sell in one year
                g_calc "$f_asset_amount_tax_able+$f_assetline_amount"
                f_asset_amount_tax_able=$g_calc_result
              fi
            elif [[ $f_assetline_type = sell ]]
            then
              g_calc "$f_asset_amount_tax_free-$f_assetline_amount"
              f_assetline_amount_left=$g_calc_result
              if g_num_is_lower_equal $f_assetline_amount_left 0
              then
                g_calc "$f_asset_amount_tax_able+$f_assetline_amount_left"
                f_asset_amount_tax_able=$g_calc_result
                f_asset_amount_tax_free=0
               else 
                f_asset_amount_tax_free=$f_assetline_amount_left
              fi
            fi
          done
          IFS=$oldIFS
          #g_echo_note "Still in Stock: Taxable: $f_asset_amount_tax_able; Tax free: $f_asset_amount_tax_free"

          if g_num_is_higher_equal $f_asset_amount_tax_free $f_asset_amount
          then
            ## completely tax free if over 1 year
            f_taxable=0
            f_one_year_ago="yes"
            # reduce tax free volume
            g_calc "$f_asset_amount_tax_free-$f_asset_amount"
            f_asset_amount_tax_free=$g_calc_result
          elif g_num_is_lower_equal $f_asset_amount_tax_free 0
          then
            ## complete taxable if under 1 year
            f_one_year_ago="no"
            f_taxable=$f_sell_result_eur
            f_tax_type="Verkauf (Einkommenssteuersatz)"
            g_calc "$f_asset_amount_tax_able-$f_asset_amount"
            f_asset_amount_tax_able=$g_calc_result
            echo "$f_date,$f_exchange,$f_currency_spent_eur_tax,$f_currency_quantity_sold_eur_tax" >> "TRANSACTIONS_OVERVIEW-trade-result_tax_german_eur.tmp"
          else
            ## partially taxable
            f_one_year_ago="partially"
            # calculate taxable num of e.g. ETH
            g_calc "$f_asset_amount-$f_asset_amount_tax_free"
            f_taxable_asset=$g_calc_result
            
            # calculate in percentage from sell sum
            g_calc "100/$f_asset_amount*$f_taxable_asset"    
            f_percentage_taxable=$g_calc_result
            
            # calculate part of sell_result from percentage from sell sum
            g_calc "$f_sell_result_eur/100*$f_percentage_taxable"
            f_tax_able=$g_calc_result            

            f_tax_type="Verkauf (Einkommenssteuersatz)"
            g_calc "$f_asset_amount_tax_able-$f_taxable_asset"

            echo "$f_date,$f_exchange,$f_currency_spent_eur_tax,$f_currency_quantity_sold_eur_tax,$f_percentage_taxable" >> "TRANSACTIONS_OVERVIEW-trade-result_tax_german_eur.tmp"

          fi
        fi
      fi

      ## Fields
      # 1 date - f_date
      # 2 exchange - f_exchange
      # 3 type - f_type
      # 4 krypto asset - f_asset
      # 5 krypto asset amount - f_asset_amount
      # 6 mutual currency - f_currency
      # 7 mutual currency amount - f_currency_amount
      # 8 tax 1 year ago yes/no/partially? - f_one_year_ago
      # 9 totally mutal currency amount (money for trade) spent - f_currency_spent
      # 10 totally krypto asset amount (got krypto in trade) - f_asset_quantity
      # 11 total result profit/loss for exchange/krypto asset - f_result
      # 12 total result of trade (from/until krypto asset amount is 0 again) - f_sell_result
      # 13 type of tax if to pay - f_tax_type
      # 14 taxable amount of trade - f_taxable
      # 15 mutual currency amount in EUR - f_currency_amount_eur
      # 16 total result profit/loss for exchange/krypto asset calculated in EUR - f_result_eur 
      # 17 total result of trade (from/until krypto asset amount is 0 again) calculated in EUR - f_sell_result_eur
      # 18 remaining krypto asset amount - f_asset_quantity_remaining
      # 19 Optional Note - f_note
      # 20 totally mutal currency amount (money for trade) spent in EUR - f_currency_spent_eur
      # 21 totally mutal currency amount (money for trade) sold - f_currency_quantity_sold
      # 22 totally mutal currency amount (money for trade) sold in EUR - f_currency_quantity_sold_eur
      # 23 f_sell_result_percentage
      # 24 f_sell_result_percentage_eur
      echo "$f_date,$f_exchange,$f_type,$f_asset,$f_asset_amount,$f_currency,$f_currency_amount,$f_one_year_ago,$f_currency_spent,$f_asset_quantity,$f_result,$f_sell_result,$f_tax_type,$f_taxable,$f_currency_amount_eur,$f_result_eur,$f_sell_result_eur,$f_asset_quantity_remaining,$f_note,$f_currency_spent_eur,$f_currency_quantity_sold,$f_currency_quantity_sold_eur,$f_sell_result_percentage,$f_sell_result_percentage_eur" | tee -a ALL_TRANSACTIONS_OVERVIEW.csv.tmp >>ALL_TRANSACTIONS_OVERVIEW.log

      if [[ $f_type =~ sell|leverage-sell ]]
      then 
        echo -e "\n"  >>ALL_TRANSACTIONS_OVERVIEW.log
      fi 

    done

    # calculate totals by exchange/asset
    f_staking_rewards_asset=$(cat ALL_TRANSACTIONS_OVERVIEW.csv.tmp | egrep ",$f_exchange,reward-staking,$f_asset," | cut -d, -f7 | awk "{ SUM += \$1} END { printf(\"%.2f\", SUM) }")
    f_giveaway_asset=$(cat ALL_TRANSACTIONS_OVERVIEW.csv.tmp | egrep ",$f_exchange,giveaway,$f_asset," | cut -d, -f7 | awk "{ SUM += \$1} END { printf(\"%.2f\", SUM) }")
    f_instant_trade_bonus_asset=$(cat ALL_TRANSACTIONS_OVERVIEW.csv.tmp | egrep ",$f_exchange,instant_trade_bonus,$f_asset," | cut -d, -f7 | awk "{ SUM += \$1} END { printf(\"%.2f\", SUM) }")
    f_tax_total=$(cat ALL_TRANSACTIONS_OVERVIEW.csv.tmp | egrep ",$f_exchange,.+,$f_asset," | cut -d, -f14 | awk "{ SUM += \$1} END { printf(\"%.10f\", SUM) }")


    echo -e "\n $f_exchange $f_asset Results:"  >>ALL_TRANSACTIONS_OVERVIEW.log
    echo " Remaining $f_asset_quantity_remaining $f_asset"  >>ALL_TRANSACTIONS_OVERVIEW.log
    echo " Straking Rewards: $f_staking_rewards_asset $f_currency"  >>ALL_TRANSACTIONS_OVERVIEW.log
    echo " Giveaways: $f_giveaway_asset $f_currency"  >>ALL_TRANSACTIONS_OVERVIEW.log
    echo " Instand Trade Bonus: $f_instant_trade_bonus_asset $f_currency"  >>ALL_TRANSACTIONS_OVERVIEW.log
    echo " Result: $f_result $f_currency ($f_result_eur EUR)"  >>ALL_TRANSACTIONS_OVERVIEW.log
    echo " German Tax: $f_tax_total EUR"  >>ALL_TRANSACTIONS_OVERVIEW.log
    echo "======================================"  >>ALL_TRANSACTIONS_OVERVIEW.log
  

  done

  mv ALL_TRANSACTIONS_OVERVIEW.csv.tmp ALL_TRANSACTIONS_OVERVIEW.csv
  mv ALL_TRANSACTIONS_OVERVIEW_WARN.csv.tmp ALL_TRANSACTIONS_OVERVIEW_WARN.csv
  mv TRANSACTIONS_OVERVIEW-trade-result_tax_german_eur.tmp TRANSACTIONS_OVERVIEW-trade-result_tax_german_eur.csv

}

