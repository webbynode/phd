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

echo "  => Configuring database..."
config_app_db $app_name > /var/log/phd/config_db.log 2>&1

echo ""
restart_webserver $already_existed

echo ""
echo "$app_name deployed successfully."
if [[ ! "$base" =~ "." ]]; then
  echo ""
  echo "Created http://$name.webbyapp.com/"
fi
echo ""
