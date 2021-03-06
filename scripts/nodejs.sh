if [[ "$WEB_SERVER" == "apache" ]]; then
  echo "Node.js Engine is not yet supported in Apache"
else
    PHD_VIRTUALHOST_TEXT='upstream app_cluster_1 {
      server 127.0.0.1:8000;
  }

  server {
      listen 0.0.0.0:80;
      server_name $host;

      location / {
          proxy_set_header X-Real-IP \$remote_addr;
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_set_header Host \$http_host;
          proxy_set_header X-NginX-Proxy true;

          proxy_pass http://app_cluster_1/;
          proxy_redirect off;
      }
  }'

  installing=0
  if [[ ! -x "/usr/local/bin/node" ]]; then
    installing=1
    echo "Adding node.js support to nginx..."

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
    git clone git://github.com/ry/node.git

    cd /tmp/node
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
      rm -fR /tmp/node
    fi
    
  fi

fi

echo "Configuring node.js application..."
configure_vhost

echo "  => Configuring database..."
sudo config_app_db $app_name > $LOG_DIR/config_db.log 2>&1

cd $dir

#script=`ls -1 *.js|tail -1`
script="index.js"
echo "  => Configuring monit..."
sudo rm /etc/monit/services/$app_name > /dev/null 2>&1
sudo echo "check host $host with address 127.0.0.1
start program = \"/usr/local/bin/node $dir/$script\"
stop program  = \"/usr/bin/pkill -f 'node $dir/$script'\"
if failed port 8000 protocol HTTP
    request /
    with timeout 10 seconds
    then restart" > /etc/monit/services/$app_name
    
echo "  => Starting app..."
sudo /etc/init.d/monit restart > $LOG_DIR/monit.log 2>&1
sleep 3
sudo monit stop $host
sleep 5
sudo monit start $host

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

sudo monit restart $host
if [ "$installing" == "1" ]; then
  restart_webserver 0
fi
