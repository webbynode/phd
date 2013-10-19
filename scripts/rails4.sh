function rake_task_defined {
  old_dir=$PWD
  cd $dir
  bundle exec rake $1 --dry-run >/dev/null 2>&1
  cd $old_dir
}

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

echo "Configuring Rails 4 application..."

configure_vhost
already_existed=$?

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
    expand_env_template "/var/webbynode/templates/rails/database_$DB_ENGINE.yml" > $dir/config/database.yml
    sed -i "s/@app_name@/$name/g" $dir/config/database.yml

    if [[ ! -z "${rails4_adapter}" ]]; then
      echo "     using adapter: ${rails4_adapter}"
      sed -i "s/adapter: mysql$/adapter: ${rails4_adapter}/g" $dir/config/database.yml
    fi
  fi
fi

cd $dir
echo "  => Bundling gems..."
unset GIT_DIR && bundle install --without test development > $LOG_DIR/bundler.log 2>&1
check_error 'bundling gems' 'bundler'

ruby -e "require 'rubygems'; require 'bundler'" -e "sqlite3 = Bundler.definition.dependencies.select { |d| d.name == 'sqlite3' }.first; exit(0) unless sqlite3; groups = sqlite3.groups - [:test, :development]; if groups.any?; exit(1); else; exit(0); end" > $LOG_DIR/check_sqlite3.log 2>&1

if [ $? -eq 1 ]; then
  echo ""
  echo "---------------------"
  echo "    W A R N I N G "
  echo "---------------------"
  echo ""
  echo "It seems that you have sqlite3 gem listed in your Gemfile. Please visit the URL:"
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

if rake_task_defined "assets:precompile"; then
  echo "  => Precompiling assets..."
  RAILS_GROUPS=assets
  RAILS_ENV=production
  bundle exec rake assets:precompile > $LOG_DIR/assets_precompile.log 2>&1
  check_error 'precompiling assets' 'assets_precompile'
fi

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

restart_webserver $already_existed
