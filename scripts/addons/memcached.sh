check_installed memcached

if [ ! -f /etc/init.d/memcached ]; then
  add_on "Memcached"
  
  add_on_wait "Installing Memcached"
  install_if_needed mongodb-stable >>/var/log/phd/memcached-install.log 2>&1
  echo ""
fi

