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


function calc_fifo_pnl {

  g_echo_note "RUNNING FUNCTION ${FUNCNAME} $@"

  # Initialize variables
  local f_csv_file="$1"
  local f_current_year=$(date +%Y)
  declare -A f_holdings
  local f_date f_action f_symbol f_crypto_amount f_fiat_currency f_fiat_amount f_exchange f_fee_currency f_fee_amount f_note f_fiat_amount_tax_currency

  # Read CSV file line by line
  while IFS=',' read -r f_date f_action f_symbol f_crypto_amount f_fiat_currency f_fiat_amount f_exchange f_fee_currency f_fee_amount f_note
  do

    ## Debug
    #[ "$f_symbol" == "ETH" ] || continue
    #[ "$f_note" == "short" ] && continue
 
    # ignore stable coins 
    [[ $f_symbol == USDT || $f_symbol == EUR ]] && continue

    # Extract year from date
    local f_year=${f_date:0:4}

    ## Debug
    #[ "$f_year" == "2024" ] || continue
    #[ "$f_action" == "fundingfee" ] && continue

    # add exchange 
    [[ "$f_exchanges" != *"$f_exchange "* ]] && f_exchanges+="$f_exchange "

    # prevent exponential numbers
    g_num_exponential2normal $f_crypto_amount
    f_crypto_amount=$g_num_exponential2normal_result
    g_num_exponential2normal $f_fiat_amount
    f_fiat_amount=$g_num_exponential2normal_result
    g_num_exponential2normal $f_fee_amount
    f_fee_amount=$g_num_exponential2normal_result

    ## Debug
    #echo "$f_date $f_symbol"
    #echo "f_fiat_amount=$f_fiat_amount"

    # convert f_fiat_currency/f_fiat_amount to TRANSFER_CURRENCY/f_fiat_amount_tax_currency if they are not equal
    if ! [[ "$f_fiat_currency" == "$TRANSFER_CURRENCY" ]] && [[ "$f_fiat_amount" != "0" ]] 
    then
      currency_converter $f_fiat_amount "$f_fiat_currency" $TRANSFER_CURRENCY "$f_date" >/dev/null
      f_fiat_amount_tax_currency=$f_currency_converter_result
    else
      f_fiat_amount_tax_currency=$f_fiat_amount
    fi
    
    ## Debug
    #echo "f_fiat_amount_tax_currency=$f_fiat_amount_tax_currency"

    # convert f_fee_currency/f_fee_amount to TRANSFER_CURRENCY/f_fiat_amount_tax_currency if present
    if [[ -n "$f_fee_amount" ]] 
    then
      currency_converter $f_fee_amount $f_fee_currency $TRANSFER_CURRENCY "$f_date" >/dev/null
      f_fee_amount=$f_currency_converter_result
      [[ $f_action == "buy" || $f_action == "leverage-buy" ]] && g_calc "$f_fiat_amount_tax_currency + $f_fee_amount"
      [[ $f_action == "sell" || $f_action == "leverage-sell" || $f_action == "liquidation" ]] && g_calc "$f_fiat_amount_tax_currency - $f_fee_amount"
      f_fiat_amount_tax_currency=$g_calc_result
    fi

    ## Debug
    #echo "f_fiat_amount_tax_currency=$f_fiat_amount_tax_currency"

    # no space in date (prevent problems mit $f_holdings)
    f_date="${f_date/ /T}"
    
    # get current holfings for determining if this is a long or short trade (f_holdings_amount)
    get_holdings_amount

    ## Debug
    #echo "f_crypto_amount=$f_crypto_amount"

    # Process fundingfee action
    if [[ $f_action == "fundingfee" ]]
    then
      process_fundingfee "$f_symbol" "$f_crypto_amount" "$f_fee_amount" "$f_date" "$f_year"
    # Process buy actions
    elif [[ $f_action == "buy" || $f_action == "leverage-buy" || $f_action == "reward-staking" || $f_action == "giveaway" || $f_action == "instant_trade_bonus" ]]
    then
      if g_num_is_higher_equal $f_holdings_amount 0
      then
        # long
        ## Debug
        #echo process_buy "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date"
        process_buy "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date"
      elif g_num_is_lower_equal "$f_holdings_amount" "-$f_crypto_amount"
      then
        # short
        ## Debug
        #echo process_sell "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date" "$f_year" short
        process_sell "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date" "$f_year" short
      else
        # long+short (partial)
        # calc long/short parts
        g_percentage-diff "-$f_crypto_amount" "$f_holdings_amount"
        g_calc "$f_fiat_amount_tax_currency/100*($g_percentage_diff_result+100)"
        f_fiat_amount_tax_currency_long=$g_calc_result
        g_calc "$f_fiat_amount_tax_currency/100*(($g_percentage_diff_result*-1))"
        f_fiat_amount_tax_currency_short=$g_calc_result
        g_calc "$f_crypto_amount/100*($g_percentage_diff_result+100)"
        f_crypto_amount_long=$g_calc_result
        g_calc "$f_crypto_amount/100*($g_percentage_diff_result*-1)"
        f_crypto_amount_short=$g_calc_result
        # part short-sell
        # part long-sell
        ## Debug
        #echo PART: process_sell process_sell "$f_symbol" "$f_crypto_amount_long" "$f_fiat_amount_tax_currency_long" "$f_date" "$f_year"
        process_sell "$f_symbol" "$f_crypto_amount_long" "$f_fiat_amount_tax_currency_long" "$f_date" "$f_year"

        ## Debug
        #echo PART: process_buy "$f_symbol" "$f_crypto_amount_long" "$f_fiat_amount_tax_currency_long" "$f_date" "$f_year"
        process_buy "$f_symbol" "$f_crypto_amount_long" "$f_fiat_amount_tax_currency_long" "$f_date" "$f_year" 
      fi
    # Process sell actions
    elif [[ $f_action == "sell" || $f_action == "leverage-sell" ||  $f_action == "liquidation" ]]
    then
      # check for long or short or log+short
      if g_num_is_higher_equal "$f_holdings_amount" "$f_crypto_amount"
      then
        # long
        ## Debug
        #echo process_sell "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date" "$f_year"
        process_sell "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date" "$f_year"
      elif g_num_is_higher "$f_holdings_amount" 0
      then
        # long+short (partial)
        # calc long/short parts
        g_percentage-diff "$f_crypto_amount" "$f_holdings_amount"
        g_calc "$f_fiat_amount_tax_currency/100*($g_percentage_diff_result+100)"
        f_fiat_amount_tax_currency_long=$g_calc_result
        g_calc "$f_fiat_amount_tax_currency/100*(($g_percentage_diff_result*-1))"
        f_fiat_amount_tax_currency_short=$g_calc_result
        g_calc "$f_crypto_amount/100*($g_percentage_diff_result+100)"
        f_crypto_amount_long=$g_calc_result
        g_calc "$f_crypto_amount/100*($g_percentage_diff_result*-1)"
        f_crypto_amount_short=$g_calc_result
        # part long-sell
        ## Debug
        #echo PART: process_sell "$f_symbol" "$f_crypto_amount_long" "$f_fiat_amount_tax_currency_long" "$f_date" "$f_year"
        process_sell "$f_symbol" "$f_crypto_amount_long" "$f_fiat_amount_tax_currency_long" "$f_date" "$f_year"
        # part short-sell
        ## Debug
        #echo PART: process_buy "$f_symbol" "$f_crypto_amount_short" "$f_fiat_amount_tax_currency_short" "$f_date" short
        process_buy "$f_symbol" "$f_crypto_amount_short" "$f_fiat_amount_tax_currency_short" "$f_date" short
      elif [[ $f_action == "liquidation" ]]
      then
        # short sell/liquidation
        ## Debug
        #echo process_sell "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date"  $f_year short
        process_sell "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date"  $f_year short
      else
        # short buy
        ## Debug
        #echo process_buy "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date" short
        process_buy "$f_symbol" "$f_crypto_amount" "$f_fiat_amount_tax_currency" "$f_date" short
      fi
    fi
   
    ## DEBUG output
    #get_holdings_amount
    #echo "f_holdings_amount=$f_holdings_amount"
    #echo "============================" 
   
  done < "$f_csv_file"
}

function process_buy {
  local f_symbol="$1" f_amount="$2" f_price="$3" f_date="$4" f_short="$5"
  local f_tax_type f_trade_tax
  # Add to holdings
  # long
  [[ -z "$f_short" ]] && f_holdings[$f_symbol]+="$f_amount:$f_price:$f_date "
  # short
  if [[ -n "$f_short" ]] 
  then
    f_holdings[$f_symbol]+="-$f_amount:$f_price:$f_date "
    f_action="${f_action}-short"
    ## Debug
    #echo ACTION:$f_action
  elif [[ $f_action == "reward-staking" ]]
  then
    f_tax_type="Sonst-Einkünfte-Staking"
  elif [[ $f_action == "giveaway" ]]
  then
    f_tax_type="Sonst-Einkünfte-Giveaway"
  elif [[ $f_action == "instant_trade_bonus" ]]
  then
    f_tax_type="Kapitalertrag-Instant-Trade-Bonus"
  fi

  if [[ -n "$f_tax_type" ]] 
  then
    f_trade_tax=$f_price
    f_fiat_amount=0
    f_fiat_amount_tax_currency=0
  fi

  get_holdings_amount
  echo "$f_date,$f_exchange,$f_action,$f_symbol,$f_amount,$f_fiat_currency,-$f_price,$f_holdings_amount,,,,,$f_tax_type,$f_trade_tax,-$f_price,,,,,,,,," >>ALL_TRANSACTIONS_OVERVIEW.csv.tmp
}

function process_sell {
  local f_symbol="$1" f_sell_amount="$2" f_sell_price="$3" f_sell_date="$4" f_year="$5" f_short="$6"
  f_remaining_sell=$f_sell_amount
  local f_profit=0 f_loss=0 f_profit_tax=0 f_loss_tax=0 f_trade_tax=0
  local f_pnl

  # define tax type
  local f_tax_type="Kapitalertrag-Derivat"
  local f_trade_result
  [[ $f_action == "sell" ]] && f_tax_type="Veräußerungsgeschäft"
  local f_buy_amount f_buy_price f_buy_date

  # Process each holding using FIFO
  while [[ $f_remaining_sell > 0 && -n "${f_holdings[$f_symbol]}" ]]
  do

    IFS=':' read -r f_buy_amount f_buy_price f_buy_date < <(echo "${f_holdings[$f_symbol]%% *}")

    # Calculate amount to sell from this holding
    f_sell_from_holding=$f_buy_amount
    [[ -n "$f_short" ]] && f_remaining_sell=-${f_remaining_sell#-}
    [[ -z "$f_short" ]] && g_num_is_lower $f_remaining_sell $f_buy_amount && f_sell_from_holding=$f_remaining_sell
    [[ -n "$f_short" ]] && g_num_is_higher $f_remaining_sell $f_buy_amount && f_sell_from_holding=$f_remaining_sell

    # calculate sell percentage of buy trade    
    ## Debug
    #echo "f_sell_from_holding=$f_sell_from_holding"
    [[ -z "$f_short" ]] && g_percentage-diff $f_buy_amount $f_sell_from_holding
    [[ -n "$f_short" ]] && g_percentage-diff $f_buy_amount $f_sell_from_holding
    g_calc "100+$g_percentage_diff_result"
    f_percentage_of_buy=${g_calc_result#-}
    
    ## Debug
    #echo "f_percentage_of_buy=$f_percentage_of_buy"

    # Calculate profit/loss (pnl)
    ## Debug
    #echo "f_sell_price=$f_sell_price"
    #echo "f_buy_price=$f_buy_price"
    # if not first iteration (f_pnl is already set from previous iteration) and partial sell
    if [[ -n "$f_pnl" ]] 
    then
      # on multiple iteration partial sell 
      g_calc "$f_pnl - ($f_buy_price/100*$f_percentage_of_buy)"
    else
      # on first interation partial sell
      g_calc "$f_sell_price - ($f_buy_price/100*$f_percentage_of_buy)"
    fi
    local f_pnl=$g_calc_result
    ## Debug
    #echo "f_pnl=$f_pnl"    

    # Check if trade is tax-free (held for more than a year)
    local f_is_taxable=true
    if [[ "$f_tax_type" == "Veräußerungsgeschäft" ]] 
    then
      local f_days_held=$(( ($(date -d "$f_sell_date" +%s) - $(date -d "$f_buy_date" +%s)) / 86400 ))
      [[ $f_days_held -gt 365 && ${f_tax_type} == "Veräußerungsgeschäft" ]] && f_is_taxable=false
    fi

    # Update remaining sell amount and holdings
    g_calc "$f_remaining_sell - $f_sell_from_holding"
    f_remaining_sell=$g_calc_result
    ## Debug
    #echo "f_remaining_sell=$f_remaining_sell"
    #echo "HOLDINGS1: ${f_holdings[$f_symbol]}"
    f_holdings[$f_symbol]="${f_holdings[$f_symbol]#* }"

    # If there's remaining amount in the holding, add it back
    [[ -z "$f_short" ]] && g_calc "$f_buy_amount - $f_sell_from_holding"
    [[ -n "$f_short" ]] && g_calc "$f_buy_amount + $f_sell_from_holding"
    g_calc "$f_buy_amount - $f_sell_from_holding"
    local f_remaining_buy_amount=$g_calc_result
    ## Debug
    #echo "f_remaining_buy_amount=$g_calc_result"
    #if g_num_is_higher $f_remaining_buy_amount 0
    if [[ "$f_remaining_buy_amount" != "0" ]] 
    then
      g_calc "$f_buy_price/100*(100-$f_percentage_of_buy)"
      f_remaining_buy_price=$g_calc_result
      f_holdings[$f_symbol]="$f_remaining_buy_amount:$f_remaining_buy_price:$f_buy_date ${f_holdings[$f_symbol]}"
    fi
    ## Debug
    #echo "HOLDINGS2: ${f_holdings[$f_symbol]}"
  done

  # Update profit/loss
  [[ -n "$f_short" ]] && g_calc "$f_pnl * -1" && f_pnl=$g_calc_result
  if g_num_is_higher $f_pnl 0
  then
    g_calc "$f_profit + $f_pnl"
    f_profit=$g_calc_result
  else
    g_calc "$f_loss - $f_pnl"
    f_loss=$g_calc_result
  fi

  # calculate result of trade
  g_calc "$f_profit - $f_loss"
  f_trade_result=$g_calc_result

  # calculate taxable part of trade
  if [[ $f_is_taxable == true ]]
  then
    g_calc "$f_trade_tax + $f_pnl"
    f_trade_tax=$g_calc_result
  fi

  get_holdings_amount

  ## DEBUG output
  #echo "f_holdings_amount=$f_holdings_amount"
  #echo "Result: $f_trade_result ; taxable=$f_is_taxable ; REMAINING: $f_holdings_amount"

  # write to csv
  if [[ -n "$f_short" ]] 
  then
    f_action="${f_action}-short"
    ## Debug
    #echo ACTION:$f_action
  fi 
  [[ "$f_trade_tax" == "0" ]] && [[ "$f_tax_type" == "Veräußerungsgeschäft" ]] && f_tax_type="Veräußerungsgeschäft Spekulationsfrist > 1 Jahr"
  echo "$f_date,$f_exchange,$f_action,$f_symbol,-$f_sell_amount,$f_fiat_currency,$f_sell_price,$f_holdings_amount,,,,,$f_tax_type,$f_trade_tax,$f_sell_price,,$f_trade_result,,,,,,," >>ALL_TRANSACTIONS_OVERVIEW.csv.tmp

  [[ -z "$f_trade_result" ]] && g_echo_error "No trade result!!! Someting wrong $f_date,$f_symbol,$f_action $f_short"

}

function get_holdings_amount {
  local block first_value
  f_holdings_amount=0

  # Durch jeden Block iterieren
  IFS=" "
  for block in ${f_holdings[$f_symbol]}
  do
    IFS=$origIFS
    # Den ersten Wert vor dem Doppelpunkt extrahieren
    first_value=${block%%:*}

    # Zum Gesamtwert addieren
    g_calc "$f_holdings_amount + $first_value"
    f_holdings_amount=$g_calc_result
  done
  IFS=$origIFS
}

function process_fundingfee {
  local f_symbol="$1" f_amount="$2" f_fiat_amount_tax_currency="$3" f_date="$4" f_year="$5"
  
  ## Debug
  #echo "adding fundingfee: $f_fiat_amount_tax_currency"

  ## add fundingfee
  [[ $f_fiat_amount_tax_currency == -* ]] && f_tax="${f_fiat_amount_tax_currency#-}"
  [[ $f_fiat_amount_tax_currency == -* ]] || f_tax="-${f_fiat_amount_tax_currency}"
  get_holdings_amount
  echo "$f_date,$f_exchange,$f_action,$f_symbol,$f_amount,$get_holdings_amount,,,,,,,Kapitalertrag-Derivat,$f_tax,$f_tax,,$f_tax,,,,,,," >>ALL_TRANSACTIONS_OVERVIEW.csv.tmp
}

#function transaction_csv_validity_ckecks {
#  local f_buy f_sell f_liquidation f_liquidation_short
#  local f_complete_result=0
#  declare -A transaction_csv_validity_ckeck_buy_sell_diff
#
#  f_symbols=$(cut -d, -f3 $f_csv_file | sort -u)
#  local f_buy_amount f_sell_amount f_tax_type 
#
#  # go through symbols and male some pre-checks
#  for f_symbol in $f_symbols
#  do
#
#    ## check asset amount
#    g_echo_note "Initial checks for $f_symbol"
#    # add all buys and sells of a symbols amount
#    f_buy=$(\
#      egrep "buy,${f_symbol},|,reward-staking,${f_symbol}|,giveaway,${f_symbol},instant_trade_bonus,${f_symbol}" "$f_csv_file" | \
#      cut -d, -f4 | \
#      awk '{ SUM += $1} END { printf("%.12f\n", SUM) }' \
#    )
#    f_sell=$(\
#      egrep "sell,${f_symbol}," "$f_csv_file" | \
#      cut -d, -f4 | \
#      awk '{ SUM += $1} END { printf("%.12f\n", SUM) }' \
#    )
#    f_liquidation=$(\
#      egrep "liquidation,${f_symbol}," "$f_csv_file" | \
#      grep -v ",short" | \
#      cut -d, -f4 | \
#      awk '{ SUM += $1} END { printf("%.12f\n", SUM) }' \
#    )
#    f_liquidation_short=$(\
#      egrep "liquidation,${f_symbol},.+,short" "$f_csv_file" | \
#      cut -d, -f4 | \
#      awk '{ SUM += $1} END { printf("%.12f\n", SUM) }' \
#    )
#
#    # add liquidations to sell
#    # long
#    g_calc "$f_sell + $f_liquidation - $f_liquidation_short"
#    f_sell=$g_calc_result
#
#    # buy should be same as sell sum to be fine - if not:
#    g_calc "$f_buy == $f_sell"
#    if ! [[ $g_calc_result == 1 ]]
#    then
#      g_echo_note "buy ($f_buy) and sell ($f_sell) amount sums are different for ${f_symbol}. Open Positions!?"
#      g_calc "$f_sell - ($f_buy)" 
#      transaction_csv_validity_ckecks[$f_symbol]=$g_calc_result
#    else
#      transaction_csv_validity_ckeck_buy_sell_diff[$f_symbol]=0
#    fi
#
#  done
#}

function print_results {

  local f_csv=ALL_TRANSACTIONS_OVERVIEW.csv
  local f_exchange_symbol f_exchange_symbol_year_tax f_amount f_result
  #transaction_csv_validity_ckecks
 
  echo "" 
  echo "Open Positions:"
  echo "==============="

  local f_exchanges_symbols=$(cut -d, -f 2,4 "$f_csv" | sort -u)
  for f_exchange_symbol in $f_exchanges_symbols
  do
    f_exchange=${f_exchange_symbol%%,*}
    f_symbol=${f_exchange_symbol#*,}
    f_amount=$(\
      egrep ",${f_exchange},.+,$f_symbol" "$f_csv" | \
      cut -d, -f5 | \
      awk '{ SUM += $1} END { printf("%.12f\n", SUM) }' \
    )
   
    f_result=$(\
      egrep ",${f_exchange},.*sell,$f_symbol|,${f_exchange},.*buy,$f_symbol" "$f_csv" | \
      #egrep "${f_exchange},.+,$f_symbol" "$f_csv" \
      cut -d, -f17 | \
      awk '{ SUM += $1} END { printf("%.2f\n", SUM) }' \
    )

    g_calc "$f_amount == 0"
    if ! [[ $g_calc_result == 1 ]]
    then
      echo "$f_exchange/$f_symbol: $f_amount"
    fi
    
  done
 
  echo ""
  echo "Profit and Loss (Tax):"
  echo "======================"

  declare -A f_taxes f_pnls
  local f_total_tax
  local f_exchanges_symbols_years_tax=$(sed 's/-/,/' "$f_csv" | cut -d, -f 1,3,5,14 | sort -u)
  for f_exchange_symbol_year_tax in $f_exchanges_symbols_years_tax
  do
    IFS=',' read -r f_year f_exchange f_symbol f_tax_type < <(echo "$f_exchange_symbol_year_tax")
    [[ -z "$f_tax_type" ]] && continue
    f_tax=$(\
      egrep "^$f_year-.+,${f_exchange},.+,${f_symbol},.+,$f_tax_type" "$f_csv" | \
      cut -d, -f14 | \
      awk '{ SUM += $1} END { printf("%.2f\n", SUM) }' \
    )
    f_pnl=$(\
      egrep "^$f_year-.+,${f_exchange},.+,${f_symbol},.+,$f_tax_type" "$f_csv" | \
      cut -d, -f17 | \
      awk '{ SUM += $1} END { printf("%.2f\n", SUM) }' \
    )
    echo "$f_year/$f_exchange/$f_symbol/$f_tax_type: $f_tax $TRANSFER_CURRENCY"
    [[ -z "${f_taxes[${f_year}_${f_exchange}_${f_tax_type}]}" ]] && f_taxes[${f_year}_${f_exchange}_${f_tax_type}]=0
    [[ -z "${f_pnls[${f_year}_${f_exchange}]}" ]] && f_pnls[${f_year}_${f_exchange}]=0
    g_calc "${f_taxes[${f_year}_${f_exchange}_${f_tax_type}]} + ($f_tax)"
    f_taxes[${f_year}_${f_exchange}_${f_tax_type}]=$g_calc_result
    g_calc "${f_pnls[${f_year}_${f_exchange}]} + ($f_pnl)"
    f_pnls[${f_year}_${f_exchange}]=$g_calc_result

  done

  echo ""
  echo "Profit and Loss (Tax per exchange):"
  echo "==================================="

  for f_tax_year in "${!f_taxes[@]}"
  do
    echo "$f_tax_year: ${f_taxes[$f_tax_year]} $TRANSFER_CURRENCY"
  done | sort

  echo ""
  echo "Profit and Loss:"
  echo "================"

  for f_pnl_year in "${!f_pnls[@]}"
  do
    echo "$f_pnl_year: ${f_pnls[$f_pnl_year]} $TRANSFER_CURRENCY"
  done | sort

}


