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

echo "Configuring Rails 3 application..."

configure_vhost
already_existed=$?

# rails2=`gem list rails | grep rails | grep \(3`
# if [ "$?" == "1" ]; then
#   echo "  => Missing Rails 3 gems, installing..."
#   sudo apt-get install -q -y libpq-dev > $LOG_DIR/rails3_prereq.log 2>&1
  
#   sudo gem install tzinfo builder memcache-client rack rack-test rack-mount erubis mail text-format thor bundler i18n rake --source http://rubygems.org/  > $LOG_DIR/rails3_install.log 2>&1
#   sudo gem install rails --source http://rubygems.org/ > $LOG_DIR/rails3_install.log 2>&1
# fi

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

if [ -z "$skipdb" ]; then
  if [[ ! -f "$dir/config/database.yml" ]]; then
    echo "  => Configuring database.yml..."
    expand_env_template "/var/webbynode/templates/rails/database.yml" > $dir/config/database.yml
    sed -i "s/@app_name@/$name/g" $dir/config/database.yml
    if grep mysql2 $dir/Gemfile >/dev/null 2>&1; then
      sed -i "s/adapter: mysql/adapter: mysql2/g" $dir/config/database.yml
    fi
    if [[ ! -z "${rails3_adapter}" ]]; then
      echo "     using adapter: ${rails3_adapter}"
      sed -i "s/adapter: mysql/adapter: ${rails3_adapter}/g" $dir/config/database.yml
    fi
    chmod git:www-data /var/webbynode/templates/rails/database.yml
  fi
fi

cd $dir
echo "  => Bundling gems..."
unset GIT_DIR && bundle install --without test development > $LOG_DIR/bundler.log 2>&1
check_error 'bundling gems' 'bundler'

ruby -e "require 'rubygems'; require 'bundler'" -e "sqlite3 = Bundler.definition.dependencies.select { |d| d.name == 'sqlite3-ruby' }.first; exit(0) unless sqlite3; groups = sqlite3.groups - [:test, :development]; if groups.any?; exit(1); else; exit(0); end" > $LOG_DIR/check_sqlite3.log 2>&1

if [ $? -eq 1 ]; then
  echo ""
  echo "---------------------"
  echo "    W A R N I N G "
  echo "---------------------"
  echo ""
  echo "It seems that you have sqlite3-ruby gem listed in your Gemfile. Please visit the URL:"
  echo ""
  echo "   http://guides.webbynode.com/articles/rapidapps/rails3warning.html"
  echo ""
  echo "If you receive the following error while starting your application:"
  echo ""
  echo "   Cannot spawn application '/var/rails/your_app': The spawn server has exited unexpectedly."
  echo ""
fi

if [ -z "$skipdb" ]; then
  echo "  => Migrating database..."
  RAILS_ENV=production bundle exec rake db:migrate > $LOG_DIR/db_migrate.log 2>&1
  check_error 'migrating database' 'db_migrate'
fi

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

restart_webserver $already_existed