if [ -s webcontrol ]
then
  g_echo_warn "pending jobs in webcontrol" 
else
  g_echo_ok "webcontrol exists and empty - jobs done"
fi

