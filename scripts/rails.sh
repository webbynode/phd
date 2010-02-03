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

echo "Configuring Rails application..."

configure_vhost
already_existed=$?

echo "  => Configuring database..."
sudo config_app_db $app_name > /var/log/phd/config_db.log 2>&1

# checks the db/username
name=$app_name
name=${name//[-._]/}
if [ ${#name} -gt 15 ]; then
  name=$(echo $name | cut -c1-15)
fi

if [[ ! -f "$dir/config/database.yml" ]]; then
  echo "  => Configuring database.yml..."
  sed "s/@app_name@/$name/g" /var/webbynode/templates/rails/database.yml > $dir/config/database.yml
fi

cd $dir
echo "  => Installing missing gems..."
sudo RAILS_ENV=production rake gems:install > /var/log/phd/gems_install.log 2>&1

echo "  => Migrating database..."
RAILS_ENV=production rake db:migrate > /var/log/phd/db_migrate.log 2>&1

sudo chown -R git:www-data * > /var/log/phd/chown.log 2>&1
cd -

restart_webserver $already_existed
