if [[ "$WEB_SERVER" == "apache" ]]; then
  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    ServerAlias $dns_alias
    DocumentRoot $dir/public
    PassengerAppRoot $dir
  </VirtualHost>'
else
  PHD_VIRTUALHOST_TEXT='upstream $app_name {
    server 127.0.0.1:5000;
  }
  
  server {
      listen 80;
      server_name $host $dns_alias;
      root $dir/public;
      
      location / {
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;

        if (-f $request_filename/index.html) {
          rewrite (.*) \$1/index.html break;
        }
        if (-f $request_filename.html) {
          rewrite (.*) \$1.html break;
        }
        if (!-f \$request_filename) {
          proxy_pass http://$app_name;
          break;
        }
      }
  }'
fi

echo "Configuring application processes..."

rails2=`gem list bundler | grep bundler`
if [ "$?" == "1" ]; then
  echo "  => Missing bundler gem, installing..."
  sudo gem install bundler > $LOG_DIR/bundler_install.log 2>&1
fi

foreman_gem=`gem list foreman | grep foreman`
if [ "$?" == "1" ]; then
  echo "  => Missing foreman gem, installing..."
  sudo gem install foreman > $LOG_DIR/foreman_install.log 2>&1
fi

if [ -f "Gemfile" ]; then
  cd $dir
  echo "  => Bundling gems..."
  unset GIT_DIR && bundle install --without test development > $LOG_DIR/bundler.log 2>&1
  check_error 'bundling gems' 'bundler'
fi

sudo foreman export upstart /etc/init -u root -a $app_name
sudo stop testapp >> $LOG_DIR/upstart_$app_name.log
sudo start testapp

configure_vhost
already_existed=$?

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

restart_webserver $already_existed