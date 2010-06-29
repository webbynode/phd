if [[ -f "$dir/.webbynode/settings" ]]; then
  vars=`cat $dir/.webbynode/settings` 
  eval $vars
fi

if [[ ! -f "$dir/settings.template.py" ]]; then 
  echo Missing settings.template.py, halting...
  exit 102
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
  
  mkdir -p $dir/apache
  echo "import os
import sys

os.environ['DJANGO_SETTINGS_MODULE'] = '$app_name.settings'

import django.core.handlers.wsgi
sys.path.append('$HOME')
application = django.core.handlers.wsgi.WSGIHandler()" > $dir/apache/django.wsgi

  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    DocumentRoot $dir

    Alias /media/ /usr/share/pyshared/django/contrib/admin/media/

    WSGIScriptAlias / $dir/apache/django.wsgi
  </VirtualHost>'
else
  echo "not supported yet"
fi

echo "Configuring Django application..."

configure_vhost
already_existed=$?

if [[ -z "$django_username" ]]; then
  django_username='admin'
  echo "     WARN: Missing django_username setting, assuming 'admin'"
fi

if [[ -z "$django_email" ]]; then
  django_email='admin@example.org'
  echo "     WARN: Missing django_email setting, assuming 'admin@example.org'"
fi

echo "  => Configuring database..."
sudo config_app_db $app_name > /var/log/phd/config_db.log 2>&1

old_dir=`pwd`

cd $dir
echo "  => Configuring server side settings.py..."
/var/webbynode/django/settings.py.sh $app_name

echo "  => Migrating database..."
python manage.py syncdb --noinput

echo "  => Creating Django superuser..."
result=`PYTHONPATH=$dir python /var/webbynode/django/create_superuser.py $django_username "$django_email" 2>&1`

if [[ $result =~ 'duplicate key value violates unique constraint "auth_user_username_key"' ]]; then
  echo "     Already created."
fi

cd $old_dir

restart_webserver 0