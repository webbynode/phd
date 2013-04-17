dump_env() {
    if [[ -d "$base_dir" ]]; then
      for f in $base_dir/*; do
        if [[ -f $f ]]; then
            key="$(basename $f)"
            val=$(cat $f)
            echo "$key=$val" >> $dir/.env
            export $key="$val"
        fi
      done
    fi
}

if [[ -f ".webbynode/vhost_$WEB_SERVER" ]]; then
  PHD_VIRTUALHOST_TEXT=`cat ".webbynode/vhost_$WEB_SERVER"`
else
    if [[ "$WEB_SERVER" == "apache" ]]; then
      PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
        ServerName $host
        ServerAlias $dns_alias
        DocumentRoot $dir/public
        PassengerAppRoot $dir
      </VirtualHost>'
    else
      PHD_VIRTUALHOST_TEXT='server {
          listen 80;
          server_name $host $dns_alias;
          root $dir/public;
          passenger_enabled on;
      }'
    fi
fi

echo "Configuring Foreman based application..."

echo "Configuring env file..."
env_dir="/var/webbynode/env/$app_name"
port_file="$env_dir/$app_name/PORT"
if [[ -f "$port_file" ]]; then
  port=$((`cat "$port_file"`))
else
  port=$((`cat /var/webbynode/env/LAST_PORT` + 1))
  mkdir -p $(dirname "$port_file")
  echo $port > "$port_file"
fi

base_dir=/var/webbynode/env
dump_env

base_dir="$env_dir"
dump_env

configure_vhost
already_existed=$?

echo "  => Configuring init scripts..."
if [ -f "/etc/init/$app_name.conf" ]; then
  sudo stop $app_name
fi

sudo foreman export upstart /etc/init -a $app_name -u git --port $port

if [ -f "/etc/init/$app_name.conf" ]; then
  sudo start $app_name
fi

if [ -z "$skipdb" ]; then
  echo "  => Configuring database..."
  sudo config_app_db $app_name > $LOG_DIR/config_db.log 2>&1
  check_error 'configuring database' 'config_db'
fi

# checks the db/username
name=$app_name
name=${name//[-._]/}
if [ ${#name} -gt 15 ]; then
  name=$(echo $name | cut -c1-15)
fi

cd $dir

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

restart_webserver $already_existed
