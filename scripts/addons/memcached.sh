check_installed memcached

if [ $? -eq 1 ]; then
  add_on "Memcached"
  
  add_on_wait "Installing Memcached"
  install_if_needed memcached >>$LOG_DIR/memcached-install.log 2>&1
  echo ""
fi

