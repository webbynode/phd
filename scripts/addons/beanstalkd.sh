check_installed beanstalkd

if [ "$installed" == "n" ]; then
  add_on "Beanstalkd"
  
  add_on_wait "Installing Beanstalkd"
  install_if_needed beanstalkd # >>$LOG_DIR/memcached-install.log 2>&1

  add_on_wait "Configuring Beanstalkd"
  sudo sed -e 's|#START=yes|START=yes|' -i /etc/default/beanstalkd 

  add_on_wait "Starting Beanstalkd"
  sudo /etc/init.d/beanstalkd
  echo ""
fi

