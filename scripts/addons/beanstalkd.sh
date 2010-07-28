check_installed beanstalkd

if [ "$installed" == "n" ]; then
  add_on "Beanstalkd"
  
  install_if_needed beanstalkd

  add_on_status "Configuring Beanstalkd"
  sudo sed -e 's|#START=yes|START=yes|' -i /etc/default/beanstalkd 

  add_on_status "Starting Beanstalkd"
  sudo /etc/init.d/beanstalkd start
  echo ""
fi

