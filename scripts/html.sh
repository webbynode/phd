if [[ "$WEB_SERVER" == "apache" ]]; then

  PHD_VIRTUALHOST_TEXT='<VirtualHost *:80>
    ServerName $host
    DocumentRoot $dir
    DirectoryIndex index.php index.html index.htm
  </VirtualHost>'
  
else

  PHD_VIRTUALHOST_TEXT='server {
      listen 80;
      server_name $host;
      
      location / {
              root   $dir;
              index  index.php index.html index.htm;
      }
  }'

fi

echo "Configuring html application..."
needs_restart=y
configure_vhost
if [ $? -eq 1 ]; then
  needs_restart=n
fi

cd $dir

sudo chown -R git:www-data * > $LOG_DIR/chown.log 2>&1
cd -

if [ "$needs_restart" == "y" ]; then
  restart_webserver 0
fi
