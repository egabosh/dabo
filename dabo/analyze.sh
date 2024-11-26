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




# cleanup
rm -r /tmp/parallel-* /tmp/overall-result-* /tmp/g_analyze.sh-*

. /etc/bash/gaboshlib.include

## Chart Part
#. dabo/functions/genchart.sh
## Chart Part End

g_nice

export FULL_LOOP=1


function g_echo_note {
 [ -z "$1" ] && return 0
 echo -en "\033[97m$(tail -n1 ${g_tmp}/$tmpfile | cut -d, -f1) \033[36mNOTE:"
 cat <<< "$@"
 echo -en "\033[0m"
}

function analyze {

  local file=$1
  g_basename ${file}
  tmpfile=${g_basename_result}

  . /etc/bash/gaboshlib.include
  g_tmp="$2"
  #for bashfunc in $(find /etc/bash/gaboshlib -type f -name "g_*.bashfunc" -o -name "g_*.sh")
  #do 
  #  . "$bashfunc"
  #done
  . dabo/functions/check_buy_conditions.sh
  . dabo/functions/check_sell_conditions.sh
  . dabo/functions/get_vars_from_csv.sh
  . dabo/functions/score.sh
  . dabo/dabo-bot.conf
  . dabo-bot.conf
  . analyze.conf

  
  [ "${ANALYZE_VERBOSE}" -eq "0" ] ||  g_echo "Analyzing file: $file"
  
  # cleanup
  f_SELL=""
  f_BUY=""
  >${g_tmp}/${tmpfile}
  >${g_tmp}/result-${tmpfile}

  #rm -rf ${g_tmp}/open-${tmpfile}
  rm -rf ${g_tmp}/interim-${tmpfile}
  rm -rf ${g_tmp}/output-${tmpfile}

  # Chart Part
  #echo "$(head -n1 ${file}),Market Perrormance,Score,Buy Score,Sell Score,InTrade,Inetrim Result" >analyze-${analyzedate}/chart-${tmpfile}
  # Chart Part End

  # create market performance array of timeframe
  for f_market_perf_line in $(cat data/botdata/MARKET_PERFORMANCE.csv | cut -d, -f1,2 | sed 's/:[0-9][0-9],/,/; s/ /-/g; s/:/-/g')
  do
    f_market_perf_date=${f_market_perf_line%,*}
    f_market_perf_date=${f_market_perf_date//[^0-9]/}
    [ -z "$f_market_perf_date" ] && continue
    f_market_perf_date=${f_market_perf_date::-1}
    f_market_perf=${f_market_perf_line#*,}
    f_market_performace_array[${f_market_perf_date}]=${f_market_perf}
  done

  # go through data of time
  local f_lines
  local f_chart_array
  mapfile -t f_lines <<<$(egrep "^${ANALYZE_TIME}" "$file" | grep -v ',,')
  local f_line
  unset f_last_lines_array

  f_verbose=">>${g_tmp}/output-${tmpfile} 2>/dev/null"
  [ "${ANALYZE_VERBOSE}" -eq "1" ] && f_verbose="2>&1 | tee -a ${g_tmp}/output-${tmpfile}"

  for f_line in "${f_lines[@]}"
  do
    f_sell_score=""
    f_buy_score=""

    # ad line to last lines array...
    f_last_lines_array+=("${f_line}")
    # ... and stop here until 4 elements are present
    #[ -z "${f_last_lines_array[3]}" ] && continue
    [ ${#f_last_lines_array[@]} -le 3 ] && continue

    echo "$line" >>${g_tmp}/${tmpfile}
 
    # get vars
    get_vars_from_csv ${g_tmp}/${tmpfile} || continue
   
    # get time from market_performance
    local f_time="${f_date%:*}"
    f_time="${f_time//[^0-9]/}"
    f_time="${f_time::-1}"

    # get market_performance from array with time
    f_market_performance=${f_market_performace_array[${f_time}]}
    [ -z "${f_market_performance}" ] && f_market_performance=${f_market_performance_before}
    f_market_performance_before=${f_market_performance}
    g_num_valid_number "${f_market_performance}" >/dev/null 2>&1 || f_market_performance=0

    if [ -n "${f_open_trade}" ]
    then
      if [ "${ANALYZE_VERBOSE}" -eq "0" ]
      then
        check_sell_conditions ${g_tmp}/${tmpfile} >>${g_tmp}/output-${tmpfile}
      else
        check_sell_conditions ${g_tmp}/${tmpfile} #| tee -a ${g_tmp}/output-${tmpfile}
      fi
      echo "${f_result}" >>${g_tmp}/interim-${tmpfile}
      eval echo "INTERIM RESULT: ${f_result}%" ${f_verbose}
    else
      if [ "${ANALYZE_VERBOSE}" -eq "0" ]
      then
        check_buy_conditions ${g_tmp}/${tmpfile} >>${g_tmp}/output-${tmpfile}
      else
        check_buy_conditions ${g_tmp}/${tmpfile} #| tee -a ${g_tmp}/output-${tmpfile}
      fi
    fi
 
    #echo "BUY: ${f_BUY}"
    if [ -n "${f_BUY}" ]
    then
      eval echo "BUY: ${f_BUY}" ${f_verbose}
      f_open_trade=1
      BUY_PRICE=$f_price
      unset f_BUY
    fi

    if [ -n "${f_SELL}" ]
    then
      eval echo "SELL: ${f_date} ${f_SELL}" ${f_verbose}
      echo "${f_real_result}" >>${g_tmp}/result-${tmpfile}
      rm -f "${f_TRADE_HIST_FILE}"
      rm -f "${f_TRADE_HIST_FILE_INTERIM}"
      eval echo "RESULT: ${f_real_result}% ${BUY_PRICE} - ${f_price}" ${f_verbose}
      unset f_open_trade
      unset f_SELL
    fi

    ## Chart Part
    #local f_intrade=0
    #local f_score=${f_buy_score}
    #local f_interim="0"
    #[ -z "${f_buy_score}" ] && f_buy_score=0
    #if [ -z "${f_sell_score}" ] 
    #then
    #  f_sell_score=0
    #else
    #  f_score=${f_sell_score}
    #  f_intrade=1
    #  f_interim=${f_real_result}
    #fi
    #f_chart_array+=("$f_line,${f_market_performance},${f_score},${f_buy_score},${f_sell_score},${f_intrade},${f_interim}")
    ## Chart Part End
  done

  ## Chart Part
  #printf '%s\n' "${f_chart_array[@]}" >>analyze-${analyzedate}/chart-${tmpfile}
  #cat analyze-${analyzedate}/chart-${tmpfile}
  ## Chart Part End

  # sell at the end to have a final result.
  #if [ -f ${g_tmp}/open-${tmpfile} ]
  if [ -n "${f_open_trade}" ]
  then
    f_SELL="SELL ${f_ASSET}: End of file/data" 
    eval echo "SELL: ${f_date} ${f_SELL}" ${f_verbose}
    echo "${f_real_result}" >>${g_tmp}/result-${tmpfile}
    eval echo "RESULT: ${f_real_result}% ${BUY_PRICE} - ${f_price}" ${f_verbose}
    unset f_open_trade
    unset f_SELL
  fi

  complete_result=0
  for result in $(cat ${g_tmp}/result-${tmpfile})
  do
    g_calc "$complete_result+$result"
    complete_result=$(echo ${g_calc_result} | xargs printf "%.2f")
  done

  g_percentage-diff $(egrep "^${ANALYZE_TIME}" "$file" | grep -v ',,' | head -n1 | cut -d, -f2) $(egrep "^${ANALYZE_TIME}" "$file" | grep -v ',,' | tail -n1 | cut -d, -f2)
  hodlresult=${g_percentage_diff_result}

  echo "COMPLETE:RESULT:$(basename "$file" | cut -d. -f1):: ${complete_result}% HODL:${hodlresult}% analyze-${analyzedate}/${tmpfile}.log $file" | perl -pe 's/ /\t/g; s/:/ /g' | tee -a ${g_tmp}/output-${tmpfile}
  echo "=====================================" >>${g_tmp}/output-${tmpfile}
  echo "${complete_result}" >>/tmp/overall-result-${tmpfile}

  cat ${g_tmp}/output-${tmpfile} >"analyze-${analyzedate}/${tmpfile}.log"

  rm ${g_tmp}/output-${tmpfile}
  rm ${g_tmp}/result-${tmpfile}

  ## Chart Part
#  if [ -s "analyze-${analyzedate}/chart-${tmpfile}" ]
#  then
#    #g_echo "generating chart for $file from analyze-${analyzedate}/chart-${tmpfile}"
#    echo "<html><head>
#<meta charset='UTF-8'>
#<meta name='viewport' content='width=device-width, initial-scale=1'>
#<link rel='stylesheet' type='text/css' href='../data/browser.css'>
#<link rel='stylesheet' type='text/css' href='../data/charts.min.css'>
#<title>analyze.sh ${ANALYZE_TIME}</title>
#</head>
#<body>
#<h1>analyze.sh ${ANALYZE_TIME}</h1>
#" >analyze-${analyzedate}/chart-${tmpfile}.html
#    echo "Price, EMA, Levels" >>analyze-${analyzedate}/chart-${tmpfile}.html
#    genchart analyze-${analyzedate}/chart-${tmpfile} 500 2,25,26,27,28,29,30,31,32,33,34,35,4,36,37,38,39 green,DarkSlateGrey,DarkSlateGrey,Gold,DarkOrange,DarkOrange,GoldenRod,GoldenRod,GoldenRod,GoldenRod,DarkOrange,DarkOrange,MidnightBlue,Indigo,DarkSlateBlue,DodgerBlue,DeepSkyBlue >>analyze-${analyzedate}/chart-${tmpfile}.html
#    echo "Score" >>analyze-${analyzedate}/chart-${tmpfile}.html
#    genchart analyze-${analyzedate}/chart-${tmpfile} 500 42,46,45,41 Green,Red,Orange >>analyze-${analyzedate}/chart-${tmpfile}.html
#    #echo "Sell Score" >>analyze-${analyzedate}/chart-${tmpfile}.html
#    #genchart analyze-${analyzedate}/chart-${tmpfile} 500 42 green,blue >>analyze-${analyzedate}/chart-${tmpfile}.html
#    echo "MACD" >>analyze-${analyzedate}/chart-${tmpfile}.html
#    genchart analyze-${analyzedate}/chart-${tmpfile} 500 8,6,7 >>analyze-${analyzedate}/chart-${tmpfile}.html
#    echo "RSIs" >>analyze-${analyzedate}/chart-${tmpfile}.html
#    genchart analyze-${analyzedate}/chart-${tmpfile} 500 10,11,12,14,15,16,17,13 >>analyze-${analyzedate}/chart-${tmpfile}.html
#    echo "</body></html>">>analyze-${analyzedate}/chart-${tmpfile}.html
#  fi
  ## Chart Part END
}

for conf in dabo-bot.conf analyze.conf
do
  . $conf
  cat $conf
done

if [ "${ANALYZE_BATCH}" -eq "0" ]
then
  cores=$(cat /proc/cpuinfo | grep "^processor.*:" | tail -n1 | perl -pe 's/processor.*: //')
  echo -n "parallel -j${cores} bash -c --" >/tmp/parallel-$$
fi

analyzedate="$(date +%Y-%m-%d--%H-%M-%S)"
mkdir "analyze-${analyzedate}"
cp dabo-bot.conf analyze.conf analyze-${analyzedate}/
cp -r strategies analyze-${analyzedate}/

analyzecounter=0

## Chart Part
#[ -e data/charts.min.css ] || wget ${g_wget_opts} -q https://raw.githubusercontent.com/ChartsCSS/charts.css/main/dist/charts.min.css -O data/charts.min.css
## Chart Part End

for file in $@
do
  echo "${file}" | egrep -q "BALANCE|-INDEX" && continue

  lines=$(egrep "^${ANALYZE_TIME}" "$file" | grep -v ',,' | wc -l)
  if [ $lines -lt 150 ]
  then
    g_echo "Only $lines lines for given timeframe (${ANALYZE_TIME}) in $file - ignoring files with less then 150!"
    continue
  fi

  if [ "${ANALYZE_BATCH}" -eq "0" ] 
  then
    echo -n " \"analyze ${file} ${g_tmp}\"" >>/tmp/parallel-$$
  else
    analyze ${file} ${g_tmp}
  fi

done

if [ "${ANALYZE_BATCH}" -eq "0" ]
then
  export -f g_echo_note
  export g_tmp
  export analyzedate
  . /tmp/parallel-$$
fi


analyzecounter=$(cat /tmp/overall-result-* | egrep -v "^0$" | wc -l)
echo "OVERALL RESULT (average): $(cat /tmp/overall-result-* | awk "{ SUM += \$1 / ${analyzecounter} } END { printf(\"%2.2f\", SUM) }")%" | tee analyze-${analyzedate}/overall-result.log
echo "OVERALL RESULT: $(cat /tmp/overall-result-* | awk '{ SUM += $1 } END { print SUM }')%" | tee analyze-${analyzedate}/overall-result.log
cat analyze-${analyzedate}/*.history.csv.log >analyze-${analyzedate}/analyze-overall.log
echo "" | tee -a analyze-${analyzedate}/overall-result.log
echo "Trades: $(grep "BUY: " analyze-${analyzedate}/analyze-overall.log | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "Trade results positive: $(grep "^RESULT: " analyze-${analyzedate}/analyze-overall.log |  grep ": [0-9]" | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "Trade results negative: $(grep "^RESULT: " analyze-${analyzedate}/analyze-overall.log |  grep ": -" | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "Trade results neutral: $(grep "^RESULT: " analyze-${analyzedate}/analyze-overall.log |  grep ": 0.00" | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "" | tee -a analyze-${analyzedate}/overall-result.log
echo "Interim results: $(grep "INTERIM RESULT: " analyze-${analyzedate}/analyze-overall.log | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "Interim results positive: $(grep "INTERIM RESULT: [0-9]" analyze-${analyzedate}/analyze-overall.log | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "Interim results negative: $(grep "INTERIM RESULT: -" analyze-${analyzedate}/analyze-overall.log | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "" | tee -a analyze-${analyzedate}/overall-result.log
echo "First interim result after BUY positive: $(grep "BUY: " -A5 analyze-${analyzedate}/analyze-overall.log |  grep "^INTERIM RESULT: [0-9]" | grep -v "0.00" | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "First interim result after BUY negative: $(grep "BUY: " -A5 analyze-${analyzedate}/analyze-overall.log |  grep "^INTERIM RESULT: -" | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log
echo "First interim result after BUY neutral 0.00: $(grep "BUY: " -A5 analyze-${analyzedate}/analyze-overall.log |  grep "^INTERIM RESULT: 0.00" | wc -l)" | tee -a analyze-${analyzedate}/overall-result.log

echo "

Complete Results" >>analyze-${analyzedate}/overall-result.log
grep "COMPLETE:RESULT:" analyze-${analyzedate}/analyze-overall.log >>analyze-${analyzedate}/overall-result.log

echo "

Trades" >>analyze-${analyzedate}/overall-result.log
egrep "BUY: |SELL: " analyze-${analyzedate}/analyze-overall.log >>analyze-${analyzedate}/overall-result.log

