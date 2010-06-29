if [[ -f "$dir/.webbynode/settings" ]]; then
  vars=`cat $dir/.webbynode/settings` 
  eval $vars
fi

if [[ -z "$django_username" ]]; then
  echo Missing django_username setting, halting installation...
fi

if [[ -z "$django_email" ]]; then
  echo Missing django_email setting, halting installation...
fi

if [[ ! -f "$dir/settings.template.py"]]; then 
  echo Missing settings.template.py, halting...
  exit 1
fi

if [[ "$WEB_SERVER" == "apache" ]]; then
  # django and apache
  install_if_needed libapache2-mod-wsgi
  install_if_needed python-setuptools
  install_if_needed python-django "sudo easy_install Django"
  
  # for pgsql
  install_if_needed python-psycopg2
  
  # for mysql
  install_if_needed python-mysqldb
  
  mkdir -p $dir/apache/django.wsgi
  echo <<EOS > $dir/apache/django.wsgi
import os
import sys

os.environ['DJANGO_SETTINGS_MODULE'] = 'mysite.settings'

import django.core.handlers.wsgi
application = django.core.handlers.wsgi.WSGIHandler()
EOS

  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    DocumentRoot $dir
    WSGIScriptAlias / $dir/apache/django.wsgi
  </VirtualHost>'
else
fi

if [[ ! -f "$dir/settings.py" ]]; then
  echo "  => Configuring server side settings.py..."
  /var/webbynode/templates/django/settings.py.sh $app_name
fi

echo "Please provide your superuser password below, if asked."
python manage.py syncdb --username=$django_username --email=$django_email
