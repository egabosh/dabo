f_up2date_files="
last_full_interval
values
values-orders
values-positions
CCXT_SUPPORTED_EXCHANGES
CCXT_BALANCE
CCXT_BALANCE_RAW
CCXT_ORDERS
CCXT_POSITIONS
CCXT_POSITIONS_RAW
score
score_hist
"

for f_up2date_file in $f_up2date_files
do
  if ! [ -s $f_up2date_file ]
  then
    g_echo_warn "$f_up2date_file empty or does not exist $(stat -c %y $f_up2date_file)" 
    continue
  fi
  if ! find "$f_up2date_file" -mmin -6 | grep -q $f_up2date_file
  then
   g_echo_warn "$f_up2date_file seems not up2date $(stat -c %y $f_up2date_file)"
  else
    g_echo_ok "$f_up2date_file seems up2date $(stat -c %y $f_up2date_file)"
  fi
done
