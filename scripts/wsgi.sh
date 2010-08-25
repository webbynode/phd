if [[ -f "$dir/.webbynode/settings" ]]; then
  vars=`cat $dir/.webbynode/settings` 
  eval $vars
fi

if [[ ! -f "$dir/settings.template.py" ]]; then 
  echo Missing settings.template.py, halting...
  exit 102
fi

# django
install_if_needed python-setuptools

# for pgsql
install_if_needed python-psycopg2

# for mysql
install_if_needed python-mysqldb

if [[ "$WEB_SERVER" == "apache" ]]; then
  # django and apache
  install_if_needed libapache2-mod-wsgi
  
  mkdir -p $dir/apache
  echo "import os
import sys

os.environ['DJANGO_SETTINGS_MODULE'] = '$app_name.settings'

import django.core.handlers.wsgi
sys.path.append('$HOME')
application = django.core.handlers.wsgi.WSGIHandler()" > $dir/apache/django.wsgi

  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    ServerAlias $dns_alias
    DocumentRoot $dir

    Alias /media/ /usr/share/pyshared/django/contrib/admin/media/

    WSGIScriptAlias / $dir/apache/django.wsgi
  </VirtualHost>'
else
  echo "import os
import sys

os.environ['DJANGO_SETTINGS_MODULE'] = '$app_name.settings'

import django.core.handlers.wsgi
sys.path.append('$HOME')
application = django.core.handlers.wsgi.WSGIHandler()
" > $dir/passenger_wsgi.py

  PHD_VIRTUALHOST_TEXT='server {
      listen 80;
      server_name $host $dns_alias;
      root $dir/public;
      passenger_enabled on;
      
      location /media {
        root /usr/share/pyshared/django/contrib/admin;
      }
  }'
  
  mkdir -p $dir/public
  mkdir -p $dir/tmp
fi

echo "Configuring WSGI application..."

configure_vhost
already_existed=$?

echo "  => Configuring database..."
sudo config_app_db $app_name > $LOG_DIR/config_db.log 2>&1

old_dir=`pwd`

if [[ "$WEB_SERVER" == "apache" ]]; then
  restart_webserver 0
else
  restart_webserver $already_existed
fi