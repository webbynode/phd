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
echo "  => Bundling gems..."
unset GIT_DIR && bundle install --without test development > /var/log/phd/bundler.log 2>&1

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
RAILS_ENV=production rake db:migrate > /var/log/phd/db_migrate.log 2>&1

sudo chown -R git:www-data * > /var/log/phd/chown.log 2>&1
cd -

restart_webserver $already_existed