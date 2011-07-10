if [[ -f "$dir/.webbynode/settings" ]]; then
  vars=`cat $dir/.webbynode/settings` 
  eval $vars
fi

# django
install_if_needed python-setuptools

# for pgsql
install_if_needed python-psycopg2

# for mysql
install_if_needed python-mysqldb

if [[ "$WEB_SERVER" == "apache" ]]; then
  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    ServerAlias $dns_alias
    DocumentRoot $dir
    <Directory $dir>
       AllowOverride all
       Options -MultiViews
    </Directory>
  </VirtualHost>'
else
  PHD_VIRTUALHOST_TEXT='server {
      listen 80;
      server_name $host $dns_alias;
      root $dir/public;
      passenger_enabled on;
  }'
fi

echo "Configuring WSGI application..."

configure_vhost
already_existed=$?

if [ -z "$skipdb" ]; then
  echo "  => Configuring database..."
  config_app_db $app_name > $LOG_DIR/config_db.log 2>&1
  check_error 'configuring database' 'config_db'
fi

old_dir=`pwd`

if [[ "$WEB_SERVER" == "apache" ]]; then
  restart_webserver 0
else
  restart_webserver $already_existed
fi