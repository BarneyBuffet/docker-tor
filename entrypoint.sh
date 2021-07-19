#!/bin/bash
set -eo pipefail

config=/tor/torrc

##############################################################################
echo_config(){
  echo -e "\\n====================================- START ${config} -===================================="
  # Display TOR torrc config in log
  cat $config
  echo -e "=====================================- END ${config} -=====================================\\n"
}

##############################################################################
## Config tor as a Socks5 proxy
##############################################################################
proxy_config(){

  # Torrc default has proxy set to '0' so we need to have a default setting
  if [[ -n "${TOR_PROXY_PORT}" ]]; then
    sed -i "/SocksPort.*/c\SocksPort ${TOR_PROXY_PORT}" $config
    echo "Updated proxy binding and port..."
  else
    sed -i "/SocksPort.*/c\SocksPort 0.0.0.0:9050" $config
    echo "Set proxy binding and port to default value..."
  fi

  # IP or IP ranges accepted by the proxy. Everything else is rejected
  if [[ -n "${TOR_PROXY_ACCEPT}" ]]; then
    sed -i "/SocksPolicy accept/c\SocksPolicy accept ${TOR_PROXY_ACCEPT}" $config
    echo "Updated proxy accept policy..."
  fi

  # Enable control port with a hashed password
  if [[ -n "${TOR_PROXY_CONTROL_PORT}" ]] && [[ -n "${TOR_PROXY_CONTROL_PASSWORD}" ]]; then
    sed -i "/ControlPort.*/c\ControlPort ${TOR_PROXY_CONTROL_PORT}" $config
    HASHED_PASSWORD=$(tor --hash-password $TOR_PROXY_CONTROL_PASSWORD)
    sed -i "/# HashedControlPassword.*/c\HashedControlPassword $HASHED_PASSWORD" $config
  # Enable control port with an authentication cookie. Else if only control port default to cookie
  elif [[ -n "${TOR_PROXY_CONTROL_PORT}" ]] && $TOR_PROXY_CONTROL_COOKIE || [[ -n "${TOR_PROXY_CONTROL_PORT}" ]]; then
    sed -i "/ControlPort.*/c\ControlPort ${TOR_PROXY_CONTROL_PORT}" $config
    sed -i "/# CookieAuthentication 1/c\CookieAuthentication 1" $config
    sed -i "/# CookieAuthFileGroupReadable 1/c\CookieAuthFileGroupReadable 1" $config
  fi

}

##############################################################################
init(){
  echo -e "\\n====================================- INITIALISING TOR -===================================="

  # Copy torrc config file into bind volume
  cp /tmp/tor/torrc* /tor/
  rm -rf /tmp/tor
  echo "Copied torrc into /tor"

  # Are we setting up a Tor proxy
  if $TOR_PROXY; then
    echo "Configuring Tor proxy..."
    proxy_config
    echo "Tor proxy configured..."
  else
    sed -i "/SocksPort.*/c\SocksPort 0" $config
    echo "Disabled Tor proxy..."
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

  # Initialise container if there is no lock file
  if [[ ! -e $config.lock ]]; then 
    init
    echo "Only run init once. Delete this file to re-init torrc on container start up." > $config.lock
  else
    echo "Torrc already configured. Skipping config templating..."
  fi

  # Echo config to log if set true
  if $TOR_LOG_CONFIG; then
    echo_config
  fi
}

main

echo -e "\\n====================================- STARTING TOR -===================================="
# Display Tor version & torrc in log
tor --version
echo ''

exec "$@"