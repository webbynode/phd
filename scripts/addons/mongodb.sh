check_installed mongodb-stable

if [ $? -eq 1 ]; then
  echo "  => Installing addon MongoDB"

  # adds 10gen repo to aptitude sources
  echo "     Adding 10gen repository..."
  sudo bash -c 'echo "deb http://downloads.mongodb.org/distros/ubuntu 10.4 10gen" >> /etc/apt/sources.list'

  # installs 10gen repo GPG key
  echo "     Acquiring 10gen gpg aptitude key..."
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
  if [ $? != 0 ]; then
    sudo apt-key adv --keyserver pool.sks-keyservers.net --recv 7F0CEB10
  fi
  sudo apt-get update >/var/log/phd/mongodb-install.log 2>&1

  echo "     Installing MongoDB..."
  echo "     This may take a few minutes, please wait..."
  install_if_needed mongodb-stable >/var/log/phd/mongodb-install.log 2>&1
  echo ""
fi

