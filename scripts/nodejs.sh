if [ "$nodejs_proxy" == "y" ]; then
  nodejs_proxy=Y
fi

installing=0
if [[ ! -x "/usr/local/bin/node" ]]; then
  installing=1
  echo "Adding node.js support to $WEB_SERVER..."
  
  test "$WEB_SERVER" == "apache" && {
    echo ""
    echo "  => Configuring Apache..."

    if [ ! -f /etc/apache2/mods-enabled/proxy.conf ]; then
      sudo a2enmod proxy proxy_http   > $LOG_DIR/apache2_modules.log 2>&1
      check_error 'configuring apache' 'apache2_modules'
    fi

    sudo sed -i 's|Order deny,allow|Order allow,deny|' /etc/apache2/mods-enabled/proxy.conf
    sudo sed -i 's|Deny from all|Allow from all|' /etc/apache2/mods-enabled/proxy.conf

    sudo /etc/init.d/apache2 reload > $LOG_DIR/apache2_reload.log 2>&1
    check_error 'reloading apache' 'apache2_reload'
  }

  echo ""
  echo "  => Installing dependencies, this will take some minutes to complete..."
  echo ""
  
  sudo apt-get -y -q install flex bison monit

  cd /tmp
  wget http://mmonit.com/monit/dist/monit-5.1.1.tar.gz
  tar -vzxf monit-5.1.1.tar.gz
  rm -fR /tmp/monit-5.1.1.tar.gz

  cd /tmp/monit-5.1.1
  ./configure
  make
  sudo make install
  sudo mkdir -p /etc/monit/services
  sudo chown -R git:www-data /etc/monit/services
  
  monit=`which monit`
  if [[ -z "$monit" ]]; then
    echo ""
    echo "     Error installing monit, aborting."
    echo ""
  else
    cd /tmp
    rm -fR /tmp/monit-5.1.1
  fi
      
  sudo echo "set daemon 30
include /etc/monit/services/*

check system nodejs
set httpd port 2812
allow admin:hello
" > /tmp/monitrc

  sudo mv /tmp/monitrc /etc
  sudo chmod 700 /etc/monitrc
  sudo chown root /etc/monitrc

  sudo cp /etc/monitrc /etc/monit/monitrc
  sudo chmod 700 /etc/monit/monitrc
  sudo chown root /etc/monit/monitrc

  sudo sed -e 's|startup=0|startup=1|' -i /etc/default/monit
  sudo cp /usr/local/bin/monit /usr/sbin
  
  if [ ! -f /etc/monitrc ]; then
    echo ""
    echo "     Error writing monit config, aborting."
    echo ""
    exit 1
  fi
  
  if [ ! -f /etc/monit/monitrc ]; then
    echo ""
    echo "     Error writing monit config, aborting."
    echo ""
    exit 1
  fi
  
  echo ""
  echo "     ~> Successfully installed monit: (`monit -V|head -1`)"
  echo ""
  
  
  echo "  => Starting monit"
  sudo /etc/init.d/monit start
  
  # wget ftp://ftp.gnu.org/pub/gnu/gnutls/gnutls-2.8.6.tar.bz2
  # tar -jxvf gnutls-2.8.6.tar.bz2
  #   
  # cd /tmp/gnutls-2.8.6
  # ./configure
  # make
  # make install

  cd /tmp
  sudo apt-get -y -q install libgcrypt-dev
  # git clone git://github.com/ry/node.git
  wget -q http://nodejs.org/dist/node-latest.tar.gz
  tar vzxf node-latest.tar.gz

  cd /tmp/node-v*
  ./configure
  make
  sudo make install
  
  node=`which node`
  if [[ -z "$node" ]]; then
    echo ""
    echo "     Error installing node.js, aborting."
    echo ""
    exit 1
  else
    echo ""
    echo "     ~> Successfully installed node.js `node -v`"
    echo ""
    
    rm /tmp/node-latest.tar.gz
    rm -fR /tmp/node-v*
  fi
  
  echo "  => Installing npm"
  
  cd /tmp
  sudo chown -R $USER /usr/local
  curl -s http://repo.webbynode.com/node/install-npm.sh | sh > $LOG_DIR/npm.log 2>&1
  check_error 'installing npm' 'npm'
  
  echo ""
  echo "     ~> Successfully installed npm `npm -v`"
  echo ""
  
fi

if [[ "$WEB_SERVER" == "apache" ]]; then
  if [ "$nodejs_proxy" == "Y" ]; then
    PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
      ServerName $host
      ServerAlias $dns_alias
      RewriteEngine On
      ProxyPass / http://127.0.0.1:$nodejs_port
      ProxyPassReverse / http://127.0.0.1:$nodejs_port
    </VirtualHost>'
  fi
else
  if [ "$nodejs_proxy" == "Y" ]; then
    PHD_VIRTUALHOST_TEXT='upstream ${app_name}_cluster {
        server 127.0.0.1:$nodejs_port;
    }

    server {
        listen 0.0.0.0:80;
        server_name $host $dns_alias;

        location / {
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header Host \$http_host;
            proxy_set_header X-NginX-Proxy true;

            proxy_pass http://${app_name}_cluster/;
            proxy_redirect off;
        }
    }'
  fi
fi

echo "Configuring node.js application..."
script="server.js"

test -f $dir/$script || {
  echo "     ERROR: Missing server.js script. Aborting installation."
  exit 1
}

port_mapping=/var/webbynode/mappings/$nodejs_port.port

if [ -f $port_mapping ]; then
  port_mapping_app=`cat $port_mapping`
  if [ ! "$port_mapping_app" == "$app_name" ]; then
    echo "     ERROR: Port $nodejs_port is already used by application $port_mapping_app"
    exit 1
  fi
  rm $port_mapping
fi

echo $app_name > $port_mapping

# adds a deletion hook
mkdir -p /var/webbynode/hooks/delete
echo "echo \"  => Removing port mapping\"
rm $port_mapping

echo \"  => Stopping node.js app...\"
sudo stop $app_name

echo \"  => Removing node.js app upstart service...\"
sudo rm /etc/init/$app_name.conf

echo \"  => Stopping monit watchdog...\"
sudo monit stop $host

echo \"  => Removing monit watchdog...\"
rm /etc/monit/services/$app_name

" > /var/webbynode/hooks/delete/$app_name

if [ "$nodejs_proxy" == "Y" ]; then
  configure_vhost
fi

if [ "$nodejs_proxy" == "y" ]; then
  configure_vhost
fi

if [ -z "$skipdb" ]; then
  echo "  => Configuring database..."
  sudo config_app_db $app_name > $LOG_DIR/config_db.log 2>&1
  check_error 'configuring database' 'config_db'
fi

cd $dir
mkdir -p $LOG_DIR/node

echo "  => Configuring upstart..."
if [ -f "/etc/init/$app_name.conf" ]; then
  echo "     Upstart script found, skipping..."
else
  sudo echo "#!upstart
  description \"$app_name node.js server\"
  author      \"Webbynode Rapp\"

  start on startup
  stop on shutdown

  script
      export HOME="$HOME"

      exec sudo -u git /usr/local/bin/node $dir/$script 2>&1 >> $LOG_DIR/node/$app_name.log 2>&1
  end script" > /tmp/$app_name.conf
  sudo mv /tmp/$app_name.conf /etc/init
  sudo chmod +x /etc/init/$app_name.conf
fi

sudo start $app_name >> $LOG_DIR/node/${app_name}_start.log 2>&1

echo "  => Configuring monit..."
sudo rm /etc/monit/services/$app_name > /dev/null 2>&1
sudo echo "#!monit
set logfile $LOG_DIR/node/$app_name_monit.log

check host $host with address 127.0.0.1
    start program = \"/sbin/start $app_name\"
    stop program  = \"/sbin/stop $app_name\"
    if failed port $nodejs_port protocol HTTP
        request /
        with timeout 10 seconds
        then restart" > /etc/monit/services/$app_name
    
echo "  => Restarting monit..."
sudo /etc/init.d/monit restart > $LOG_DIR/monit.log 2>&1

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1

if [ "$installing" == "1" ]; then
  restart_webserver 0
else
  if [[ "$WEB_SERVER" == "nginx" ]]; then
    `sudo /etc/init.d/nginx reload` >> $LOG_DIR/nginx_reload.log 2>&1
  fi
fi
