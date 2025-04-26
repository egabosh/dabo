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


function genchart {
  # generate css chart (line diagram) from csv file or simple file with number per line - needed charts.css included in webppage
  local mark
  local lastmark
  local file=$1
  local lastlines=$2
  [[ -z "${lastlines}" ]]  && lastlines=50
  local fields=$3
  [[ -z "${fields}" ]]  && fields=1
  local colors=$4
  [[ -z "${colors}" ]]  && colors="White,Gold,Silver,Blue,DarkMagenta,DarkViolet,Indigo,MediumBlue,DarkOrchid,MidnightBlue,CornflowerBlue,CadetBlue,DarkCyan,DarkSlateBlue,DeepSkyBlue,DodgerBlue,Teal"

  local f_tmp="${g_tmp}/$RANDOM"
  local f_tmp_data="${f_tmp}/g_genchart/data"
  local f_tmp_headline="${f_tmp}/g_genchart/headline"
  local f_tmp_legend="${f_tmp}/g_genchart/legend"
  mkdir -p ${f_tmp}/g_genchart

  local awkfields=$(echo "${fields}" | sed 's/,/ \",\" \$/g; s/^/\$/')
  #tail -n ${lastlines} "${file}" | cut -d, -f${fields} | egrep "^[-0-9]" >${f_tmp_data}
  tail -n ${lastlines} "${file}" | awk -F',' "{ print $awkfields }" | perl -pe 's/,,+//g' | egrep "^[-0-9]" >${f_tmp_data}
  lines=$(cat ${f_tmp_data} | wc -l)
  #head -n1 "${file}" | cut -d, -f${fields} >${f_tmp_headline}
  head -n1 "${file}" | awk -F',' "{ print $awkfields }" >${f_tmp_headline}

  local time_from=$(tail -n ${lastlines} "${file}" | head -n1 | cut -d, -f1)
  local time_to=$(tail -n1 "${file}" | cut -d, -f1)

  local highest=$(cat ${f_tmp_data} | sed 's/,/\n/g' | sort -n | egrep "^[-0-9]" | tail -n1 | sed 's/^-//')
  local lowest=$(cat ${f_tmp_data} | sed 's/,/\n/g' | sort -n | egrep "^[-0-9]" | head -n1)
  if echo ${lowest} | grep -q '^-'
  then
    lowest=$(echo ${lowest} | sed 's/^-//')
    local calc="+ ${lowest}) / (${highest} + ${lowest}"
    local calcnull="(0 $calc)"
  else
    local calc="- ${lowest}) / (${highest} - ${lowest}"
    local calcnull="0"
  fi
  
  #local divideby=$(echo "$highest+$lowest" | bc -l | sed 's/^\./0./; s/^-\./-0./')

  local fieldsnum=$(cat ${f_tmp_headline} | sed 's/,/\n/g' | wc -l)

  local color="green"
  tail -n1 ${f_tmp_data} | cut -d, -f1 | grep -q "^-" && color="red"

  local RND=$RANDOM
  echo "<table id='noborder' width='100%'><tr><td id='noborder' width='100%'>"
  echo "<div id='$RND'>"
  echo "<table class='charts-css line show-data-on-hover'><caption> $RND </caption>"
  local line
  for fieldnum in $(seq ${fieldsnum} | tac)
  do
    linecolor=$(echo "$colors" | cut -d, -f${fieldnum})
    linename=$(cat ${f_tmp_headline} | cut -d, -f${fieldnum} | tr [:lower:] [:upper:])
    linelastvalue=$(tail -n1 ${f_tmp_data} | cut -d, -f${fieldnum})
    if [[ ${fieldnum} -eq 1 ]]  
    then
      echo "<p class='legend'><font color='${color}'>${linename} (${linelastvalue})</font></p>"
    else
      echo "<p class='legend'><font color='${linecolor}'>${linename} (${linelastvalue})</font></p>"
    fi >>${f_tmp_legend}
    local linenum=1
    for line in $(cat ${f_tmp_data})
    do
      for mark in $(echo ${line} | cut -d, -f${fieldnum})
      do
        [[ -z "${lastmark}" ]]  && lastmark=${mark}
        local calcstart="(${lastmark} ${calc})"
        local calcend="(${mark} ${calc})"
        if [[ ${fieldnum} -eq 1 ]] 
        then
          echo "<td style='--color: grey; --start: calc( ${calcnull} ); --end: calc( ${calcnull} );'> </td>"
          echo "<td style='--color: ${color}; --start: calc( ${calcstart} ); --end: calc( ${calcend} );'> <span class='tooltip'> ${mark} </span> </td>"
        else
          echo "<td style='--color: ${linecolor}; --start: calc( ${calcstart} ); --end: calc( ${calcend} );'> </td>"
        fi >>${f_tmp}/g_genchart/${linenum}
        ((linenum=linenum+1))
        lastmark=${mark}
      done
    done
  done

  # put all lines together
  for linenum in $(seq 2 ${lines})
  do
    echo "<tr>"
    cat ${f_tmp}/g_genchart/${linenum}
    echo "</tr>"
  done
  echo "</table></div>"

  # legend
  if grep -q ',' ${f_tmp_headline}
  then
    echo "<td id='noborder'>"
    tac ${f_tmp_legend}
    echo "</td>"
  fi

  if echo ${time_from} | egrep -q '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]' && echo ${time_to} | egrep -q '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]'
  then
    echo "</tr><td id='noborder'><table width='100%' id='noborder'><tr><td id='noborder'><p style='text-align:left;'>${time_from}</p></td><td id='noborder' width='100%'><hr></td><td id='noborder'><p style='text-align:right;'>${time_to}</p></td></tr></table></td><td id='noborder'></td>"
  fi

  echo "</tr></table>"

  rm -r ${f_tmp}/g_genchart
  
}
