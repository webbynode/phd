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
install_if_needed python-django "sudo easy_install Django"

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
  PHD_VIRTUALHOST_TEXT='server {
      listen 80;
      server_name $host $dns_alias;
      
      location /media {
        root /usr/share/pyshared/django/contrib/admin;
      }
      
      location / {
        # host and port to fastcgi server
        fastcgi_pass 127.0.0.1:3000;
        fastcgi_param PATH_INFO \$fastcgi_script_name;
        fastcgi_param REQUEST_METHOD \$request_method;
        fastcgi_param QUERY_STRING \$query_string;
        fastcgi_param CONTENT_TYPE \$content_type;
        fastcgi_param CONTENT_LENGTH \$content_length;
        fastcgi_pass_header Authorization;
        fastcgi_intercept_errors off;
      }
  }'
  
  fastcgi_install=n
  if [[ ! -f "/etc/init.d/fastcgi" ]]; then
    fastcgi_install=y
    
    echo "Configuring Django fastcgi support..."
    install_if_needed python-flup

    mkdir -p /var/webbynode/django/run
    chown -R git:www-data /var/webbynode/django/run
    
    sudo echo "#! /bin/sh
### BEGIN INIT INFO
# Provides:          FastCGI servers for Django
# Required-Start:    networking
# Required-Stop:     networking
# Default-Start:     2 3 4 5
# Default-Stop:      S 0 1 6
# Short-Description: Start FastCGI servers with Django.
# Description:       Django, in order to operate with FastCGI, must be started
#                    in a very specific way with manage.py. This must be done
#                    for each DJango web server that has to run.
### END INIT INFO
#
# Author:  Guillermo Fernandez Castellanos
#          <guillermo.fernandez.castellanos AT gmail.com>.
#
# Version: @(#)fastcgi 0.1 11-Jan-2007 guillermo.fernandez.castellanos AT gmail.com
#

#### SERVER SPECIFIC CONFIGURATION
DJANGO_SITES=\"$app_name\"
SITES_PATH=$HOME
RUNFILES_PATH=/var/webbynode/django/run
HOST=127.0.0.1
PORT_START=3000
RUN_AS=git
FCGI_METHOD=threaded
#### DO NOT CHANGE ANYTHING AFTER THIS LINE!

set -e

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DESC=\"FastCGI servers\"
NAME=\$0
SCRIPTNAME=/etc/init.d/\$NAME

#
#       Function that starts the daemon/service.
#
d_start()
{
    # Starting all Django FastCGI processes
    PORT=\$PORT_START
    for SITE in \$DJANGO_SITES
    do
        echo -n \", \$SITE\"
        if [ -f \$RUNFILES_PATH/\$SITE.pid ]; then
            echo -n \" already running\"
        else
            start-stop-daemon --start --quiet \
                       --pidfile \$RUNFILES_PATH/\$SITE.pid \
                       --chuid \$RUN_AS --exec /usr/bin/env -- python \
                       \$SITES_PATH/\$SITE/manage.py runfcgi \
                       method=\$FCGI_METHOD \
                       host=\$HOST port=\$PORT pidfile=\$RUNFILES_PATH/\$SITE.pid
            chmod 400 \$RUNFILES_PATH/\$SITE.pid
        fi
        PORT=\$(( \$PORT + 1 ))
    done
}

#
#       Function that stops the daemon/service.
#
d_stop() {
    # Killing all Django FastCGI processes running
    for SITE in \$DJANGO_SITES
    do
        echo -n \", \$SITE\"
        start-stop-daemon --stop --quiet --pidfile \$RUNFILES_PATH/\$SITE.pid \
                          || echo -n \" not running\"
        if [ -f \$RUNFILES_PATH/\$SITE.pid ]; then
           rm \$RUNFILES_PATH/\$SITE.pid
        fi
    done
}

ACTION=\"\$1\"
case \"\$ACTION\" in
    start)
        echo -n \"Starting \$DESC: \$NAME\"
        d_start
        echo \".\"
        ;;

    stop)
        echo -n \"Stopping \$DESC: \$NAME\"
        d_stop
        echo \".\"
        ;;

    restart|force-reload)
        echo -n \"Restarting \$DESC: \$NAME\"
        d_stop
        sleep 1
        d_start
        echo \".\"
        ;;

    *)
        echo \"Usage: \$NAME {start|stop|restart|force-reload}\" >&2
        exit 3
        ;;
esac

exit 0" > /tmp/fastcgi

    sudo mv /tmp/fastcgi /etc/init.d/fastcgi
    sudo chmod +x /etc/init.d/fastcgi
    sudo update-rc.d fastcgi defaults
  fi
  
  echo ""
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
sudo config_app_db $app_name > $LOG_DIR/config_db.log 2>&1

old_dir=`pwd`

cd $dir
echo "  => Configuring server side settings.py..."
/var/webbynode/django/settings.py.sh $app_name

echo "  => Sync'ing database..."
python manage.py syncdb --noinput

echo "  => Creating Django superuser..."
result=`PYTHONPATH=$dir python /var/webbynode/django/create_superuser.py $django_username "$django_email" 2>&1`

if [[ $result =~ 'duplicate key value violates unique constraint "auth_user_username_key"' ]]; then
  echo "     Already created."
fi

cd $old_dir

if [[ "$WEB_SERVER" == "apache" ]]; then
  restart_webserver 0
else
  if [[ "$fastcgi_install" == "y" ]]; then
    restart_webserver 0
  fi

  echo ""
  sudo /etc/init.d/fastcgi restart
fi