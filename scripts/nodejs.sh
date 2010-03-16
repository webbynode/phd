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

  if [[ ! -x "/usr/local/bin/node" ]]; then
    echo "Adding node.js support to nginx..."

    echo "  => Installing dependencies, this can take a few minutes..."
    
    apt-get -y -q install flex bison

    cd /tmp
    http://mmonit.com/monit/dist/monit-5.1.1.tar.gz
    tar -vzxf monit-5.1.1.tar.gz

    cd /tmp/monit-5.1.1
    make
    sudo make install
    sudo mkdir -p /etc/monit/services
    sudo chown -R git:www-data /etc/monit/services
    
    sudo echo "set daemon 30
include /etc/monit/services/*

check system nodejs
set httpd port 2812
  allow admin:hello
" > /etc/monit/monitrc
    sudo chmod 700 /etc/monitrc
    sudo sed -e 's|startup=0|startup=1|' -i /etc/default/monit
    sudo cp /usr/local/bin/monit /usr/sbin
    
    echo "  => Starting monit"
    sudo /etc/init.d/monit start
    
    cd /tmp
    sudo apt-get -y -q install libgcrypt-dev
    wget ftp://ftp.gnu.org/pub/gnu/gnutls/gnutls-2.8.6.tar.bz2
    tar -jxvf gnutls-2.8.6.tar.bz2
  
    cd /tmp/gnutls-2.8.6
    ./configure
    make
    make install

    git clone git://github.com/ry/node.git

    cd /tmp/node
    ./configure
    make
    make install
  fi

fi

echo "Configuring node.js application..."
configure_vhost

echo "  => Configuring database..."
sudo config_app_db $app_name > /var/log/phd/config_db.log 2>&1

cd $dir

script=`ls -1 *.js|tail -1`
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
sudo monit start $app_name

sudo chown -R git:www-data * > /var/log/phd/chown.log 2>&1
cd -

sudo monit restart $host
#restart_webserver 0
