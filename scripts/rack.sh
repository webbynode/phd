if [[ "$WEB_SERVER" == "apache" ]]; then
  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    DocumentRoot $dir/public
    PassengerAppRoot $dir
  </VirtualHost>'
else
  PHD_VIRTUALHOST_TEXT='server {
      listen 80;
      server_name $host;
      root $dir/public;
      passenger_enabled on;
  }'
fi

echo "Configuring Rack application..."

configure_vhost
already_existed=$?

if [[ ! -d "$dir/public" ]]; then
  echo "     WARNING: Missing public folder in your Rack app, it'll not run smoothly!"
fi

echo "  => Configuring database..."
config_app_db $app_name > $LOG_DIR/config_db.log 2>&1

echo ""
restart_webserver $already_existed
