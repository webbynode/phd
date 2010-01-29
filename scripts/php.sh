if [[ "$WEB_SERVER" == "apache" ]]; then
  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    DocumentRoot $dir
  </VirtualHost>'
else
  PHD_VIRTUALHOST_TEXT='server {
      listen 80;
      server_name $host;
      root $dir;
  }'
fi

echo "Configuring PHP application..."
configure_vhost

echo "  => Configuring database..."
sudo config_app_db $app_name > /var/log/phd/config_db.log 2>&1

cd $dir

sudo chown -R git:www-data * > /var/log/phd/chown.log 2>&1
cd -

restart_webserver 0
