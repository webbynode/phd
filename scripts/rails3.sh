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

rails2=`gem list rails | grep rails | grep \(3`
if [ "$?" == "1" ]; then
  echo "  => Missing Rails 3 gem, installing..."
  sudo apt-get install -q -y libpq-dev > $LOG_DIR/rails3_prereq.log 2>&1
  
  sudo gem install tzinfo builder memcache-client rack rack-test rack-mount erubis mail text-format thor bundler i18n rake --source http://gemcutter.org/  > $LOG_DIR/rails3_install.log 2>&1
  sudo gem install rails --pre --source http://gemcutter.org/ > $LOG_DIR/rails3_install.log 2>&1
fi

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
echo "  => Bundling gems..."
unset GIT_DIR && bundle install --without test development > $LOG_DIR/bundler.log 2>&1

ruby -e "require 'rubygems'; require 'bundler'" -e "sqlite3 = Bundler.definition.dependencies.select { |d| d.name == 'sqlite3-ruby' }.first; exit(0) unless sqlite3; groups = sqlite3.groups - [:test, :development]; if groups.any?; exit(1); else; exit(0); end"

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

echo "  => Migrating database..."
RAILS_ENV=production rake db:migrate > $LOG_DIR/db_migrate.log 2>&1

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

restart_webserver $already_existed