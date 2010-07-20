if [ ! -f /etc/init.d/redis ]; then
  add_on "Redis"

  add_on_status "Installing prerequisite cronolog"
  install_if_needed cronolog 
  #>> $LOG_DIR/redis.log 2>&1

  cd /usr/src
  add_on_status "Downloading redis"
  echo ""
  sudo wget --quiet http://redis.googlecode.com/files/redis-1.2.6.tar.gz  2>&1 | sed 's/^/     /'
  # >> $LOG_DIR/redis.log 2>&1
  sudo tar vzxf redis-1.2.6.tar.gz  2>&1 | sed 's/^/     /'
  # >> $LOG_DIR/redis.log 2>&1
  sudo rm redis-1.2.6.tar.gz
  cd redis-*

  add_on_status "Compiling redis"
  echo ""
  sudo make >> $LOG_DIR/redis.log  2>&1 | sed 's/^/     /'
  #2>&1

  add_on_status "Installing redis"
  sudo cp redis.conf /etc

  sudo bash -c 'echo "
  daemonize no
  logfile stdout" >> /etc/redis.conf'

  sudo bash -c 'echo "nohup /usr/bin/redis-server /etc/redis.conf | /usr/sbin/cronolog /var/log/redis/redis.%Y-%m-%d.log 2>&1 &" > /etc/init.d/redis'

  add_on_status "Starting redis"
  sudo /etc/init.d/redis >> $LOG_DIR/redis.log 2>&1
  
  echo ""
fi