function get_asset_histfiles {

  g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@"
  trap 'g_echo_debug "RUNNING FUNCTION ${FUNCNAME} $@ END"' RETURN

  local f_asset f_eco_asset f_marketdata_asset

  get_symbols_ticker
  for f_asset in "${ASSETS[@]}"
  do
    f_asset_histfiles+=( asset-histories/"${f_asset}".history.{[145][dhwmM],15m}.csv )
  done
  for f_eco_asset in $ECO_ASSETS
  do
    f_asset_histfiles+=( asset-histories/ECONOMY_${f_eco_asset}.history.{[145][dhwmM],15m}.csv )
  done
  [[ -s MARKETDATA_ACTIVE ]] && for f_marketdata_asset in $(cat MARKETDATA_ACTIVE)
  do
    f_asset_histfiles+=( asset-histories/MARKETDATA_${f_marketdata_asset}.history.{[145][dhwmM],15m}.csv )
  done
}

