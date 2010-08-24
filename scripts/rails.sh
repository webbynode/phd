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

# Checks Rails version
if [ -f "$dir/config/environment.rb" ]; then
  rails_version=`grep RAILS_GEM_VERSION $dir/config/environment.rb | sed "s/RAILS_GEM_VERSION = \'\(.*\)\'.*/\1/"`
  
  echo "  => Detected Application running Rails $rails_version"
  gem=`gem list rails | grep rails | grep $rails_version`
  
  if [[ "$?" == "1" ]]; then
    echo "  => Missing Rails $rails_version gem, installing..."
    sudo gem install -v=$rails_version rails > $LOG_DIR/rails_install.log
  fi
fi

configure_vhost
already_existed=$?

echo "  => Configuring database..."
sudo config_app_db $app_name > $LOG_DIR/config_db.log 2>&1

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

check_bundler
if [ "$?" == "0" ]; then
  echo "  => Installing missing gems..."
  sudo RAILS_ENV=production rake gems:install > $LOG_DIR/gems_install.log 2>&1
  if [ "$?" != "0" ]; then
    echo "  -----------------------------------------------------"
    echo "    There was an error installing gems:"
    echo ""
    cat $LOG_DIR/gems_install.log | sed 's/^/     /'
    exit 1
  fi
fi

echo "  => Migrating database..."
RAILS_ENV=production rake db:migrate > $LOG_DIR/db_migrate.log 2>&1

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

restart_webserver $already_existed
