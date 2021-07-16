#!/bin/bash
set -eo pipefail

##############################################################################
echo_config(){
  echo -e "\\n====================================- START TOR CONFIG -===================================="
  # Display TOR torrc config in log
  cat /tor/torrc
  echo -e "=====================================- END TOR CONFIG -=====================================\\n"
}

##############################################################################
## Config tor as a Socks5 proxy
##############################################################################
proxy_config(){

  # Torrc default has proxy set to '0' so we need to have a default setting
  if [[ -n "${TOR_PROXY_PORT}" ]]; then
    sed -i "/SocksPort.*/c\SocksPort ${TOR_PROXY_PORT}" /tor/torrc
    echo "Updated proxy binding and port..."
  else
    sed -i "/SocksPort.*/c\SocksPort 0.0.0.0:9050" /tor/torrc
    echo "Set proxy binding and port to default value..."
  fi

  # IP or IP ranges accepted by the proxy. Everything else is rejected
  if [[ -n "${TOR_PROXY_ACCEPT}" ]]; then
    sed -i "/SocksPolicy accept/c\SocksPolicy accept ${TOR_PROXY_ACCEPT}" /tor/torrc
    echo "Updated proxy accept policy..."
  fi

  # Enable control port with a hashed password
  if [[ -n "${TOR_PROXY_CONTROL_PORT}" ]] && [[ -n "${TOR_PROXY_CONTROL_PASSWORD}" ]]; then
    sed -i "/ControlPort.*/c\ControlPort ${TOR_PROXY_CONTROL_PORT}" /tor/torrc
    HASHED_PASSWORD=$(tor --hash-password $TOR_PROXY_CONTROL_PASSWORD)
    sed -i "/# HashedControlPassword.*/c\HashedControlPassword $HASHED_PASSWORD" /tor/torrc
  # Enable control port with an authentication cookie. Else if only control port default to cookie
  elif [[ -n "${TOR_PROXY_CONTROL_PORT}" ]] && $TOR_PROXY_CONTROL_COOKIE || [[ -n "${TOR_PROXY_CONTROL_PORT}" ]]; then
    sed -i "/ControlPort.*/c\ControlPort ${TOR_PROXY_CONTROL_PORT}" /tor/torrc
    sed -i "/# CookieAuthentication 1/c\CookieAuthentication 1" /tor/torrc
    sed -i "/# CookieAuthFileGroupReadable 1/c\CookieAuthFileGroupReadable 1" /tor/torrc
  fi

}

##############################################################################
init(){
  echo -e "\\n====================================- INITIALISING TOR -===================================="

  # Are we setting up a Tor proxy
  if $TOR_PROXY; then
    echo "Configuring Tor proxy..."
    proxy_config
    echo "Tor proxy configured..."
  else
    sed -i "/SocksPort.*/c\SocksPort 0" /tor/torrc
    echo "Updated proxy binding and port..."
  fi

  # Are we setting up a Tor hidden service
  if $TOR_SERVICE; then
    # echo "Configuring Tor hidden service..."
    echo "Tor hidden service not supported in the docker image yet!"
  fi

  # Are we setting up a Tor relay
  if $TOR_RELAY; then
    echo "Tor relay no supported in the docker image yet!"
  fi
}

##############################################################################
main() {

  # Initialise container
  if [[ ! -e /tor/torrc.lock ]]; then 
    init
    echo "Only run init once. Delete this file to re-init torrc on container start up." > /tor/torrc.lock
  else
    echo "Torrc already configured..."
  fi

  # Echo config to log
  echo_config
}

main

echo -e "\\n====================================- STARTING TOR -===================================="
# Display Tor version & torrc in log
tor --version
echo ''

exec "$@"