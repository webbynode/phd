check_installed mongodb-stable

if [ "$installed" == "n" ]; then
  add_on "MongoDB"

  # adds 10gen repo to aptitude sources
  add_on_status "Adding 10gen repository"
  sudo bash -c 'echo "deb http://downloads.mongodb.org/distros/ubuntu 10.4 10gen" >> /etc/apt/sources.list'

  # installs 10gen repo GPG key
  add_on_status "Acquiring 10gen gpg aptitude key"
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
  if [ $? != 0 ]; then
    sudo apt-key adv --keyserver pool.sks-keyservers.net --recv 7F0CEB10
  fi
  sudo apt-get update >$LOG_DIR/mongodb-install.log 2>&1

  add_on_wait "Installing MongoDB"
  install_if_needed mongodb-stable >>$LOG_DIR/mongodb-install.log 2>&1
  echo ""
fi

