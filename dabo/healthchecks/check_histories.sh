
get_asset_histfiles

# iterate through histfiles
for f_histfile in ${f_asset_histfiles[@]}
do
  echo "checking $f_histfile"
  check_up2date_data "$f_histfile"
done

