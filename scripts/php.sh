if [[ "$WEB_SERVER" == "apache" ]]; then
  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    DocumentRoot $dir
    DirectoryIndex index.php index.html index.htm
  </VirtualHost>'
  
  if [[ ! -x "/usr/bin/php" ]]; then
    echo "Adding PHP support to Apache..."

    echo "  => Installing dependencies, this can take a few minutes..."
    echo ""
    
    sudo apt-get -y -q install php5-cgi php5-mysql php5-curl php5-gd php5-idn php-pear php5-imagick php5-imap php5-mcrypt php5-memcache php5-mhash php5-ming php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl libapache2-mod-php5 libapache2-mod-auth-mysql php5-mysql php5-pgsql 2>&1 | sed 's/^/     /'
  fi
  
else
  PHD_VIRTUALHOST_TEXT='server {
      listen 80;
      server_name $host;
      
      location / {
              root   $dir;
              index  index.php index.html index.htm;
      }

      location ~ \.php$ {
              fastcgi_pass   127.0.0.1:9000;
              fastcgi_index  index.php;
              fastcgi_param  SCRIPT_FILENAME   $dir\$fastcgi_script_name;
              include        fastcgi_params;
      }
  }'

  if [[ ! -x "/usr/bin/php" ]]; then
    echo "Adding PHP support to nginx..."

    echo "  => Installing dependencies, this can take a few minutes..."
    sudo apt-get -y -q install php5-cli php5-cgi php5-mysql php5-pgsql php5-curl php5-gd php5-idn php-pear php5-imagick php5-imap php5-mcrypt php5-memcache php5-mhash php5-ming php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl lighttpd 2>&1 | sed 's/^/     /'

    sudo /etc/init.d/lighttpd stop > /dev/null 2>&1
    sudo update-rc.d -f lighttpd remove

    echo "  => Spawning fastcgi..."
    sudo /usr/bin/spawn-fcgi -a 127.0.0.1 -p 9000 -u www-data -g www-data -f /usr/bin/php5-cgi -P /var/run/fastcgi-php.pid

    echo "#\!/bin/sh -e
/usr/bin/spawn-fcgi -a 127.0.0.1 -p 9000 -u www-data -g www-data -f /usr/bin/php5-cgi -P /var/run/fastcgi-php.pid
" > /tmp/fcgi-php

    sudo mv /tmp/fcgi-php /etc/init.d/fcgi-php
    sudo chmod +x /etc/init.d/fcgi-php
    sudo update-rc.d fcgi-php start 51 S .
  
    echo "Done!"
    echo ""
  fi
fi

echo "Configuring PHP application..."
needs_restart=y
configure_vhost
if [ $? -eq 1 ]; then
  needs_restart=n
fi

echo "  => Configuring database..."
sudo config_app_db $app_name > $LOG_DIR/config_db.log 2>&1

cd $dir

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

if [ "$needs_restart" == "y" ]; then
  restart_webserver 0
fi
