#!/bin/bash
set -eo pipefail

# Set config file variable
TOR_CONFIG_FILE=/tor/torrc
SERVICE_DIR=/tor/hidden_services

##############################################################################
## Display TOR torrc config in log
##############################################################################
echo_config(){
  echo -e "\\n====================================- START ${TOR_CONFIG_FILE} -===================================="
  cat $TOR_CONFIG_FILE
  echo -e "=====================================- END ${TOR_CONFIG_FILE} -=====================================\\n"
}

##############################################################################
## Config tor as a Socks5 proxy
##############################################################################
proxy_config(){

  ## Torrc default has proxy set to '0' so we need to have a default setting
  if [[ -n "${TOR_PROXY_PORT}" ]]; then
    sed -i "/SocksPort.*/c\SocksPort ${TOR_PROXY_PORT}" $TOR_CONFIG_FILE
    echo "Updated proxy binding and port..."
  fi

  ## IP or IP ranges accepted by the proxy. Everything else is rejected
  if [[ -n "${TOR_PROXY_ACCEPT}" ]]; then
    sed -i "/SocksPolicy accept/c\SocksPolicy ${TOR_PROXY_ACCEPT}" $TOR_CONFIG_FILE
    echo "Updated proxy accept policy..."
  fi
}

control_config(){
  ## If we have a password hash it and set
  if [[ -n "${TOR_CONTROL_PASSWORD}" ]]; then
    sed -i "/# ControlPort.*/c\ControlPort ${TOR_CONTROL_PORT}" $TOR_CONFIG_FILE
    HASHED_PASSWORD=$(tor --hash-password $TOR_CONTROL_PASSWORD)
    sed -i "/# HashedControlPassword.*/c\HashedControlPassword $HASHED_PASSWORD" $TOR_CONFIG_FILE
    echo "Opened control port to ${TOR_CONTROL_PORT} with a password..."
  fi

  ## Cookie function because it is used twice below
  control_cookie_config(){
    ## Set control port in config
    sed -i "/# ControlPort.*/c\ControlPort ${TOR_CONTROL_PORT}" $TOR_CONFIG_FILE
    ## Set control cookie true in config
    sed -i "/# CookieAuthentication 1/c\CookieAuthentication 1" $TOR_CONFIG_FILE
    ## Symbolic link torr to default location for nyx
    mkdir -p /home/tor/.tor
    ln -s /tor/control_auth_cookie /home/tor/.tor/control_auth_cookie
    echo "Opened control port to ${TOR_CONTROL_PORT} with an authorisation cookie..."
  }

  ## If cookie is true then set 1
  if $TOR_CONTROL_COOKIE; then
    control_cookie_config
  fi

  ## If we don't have a password and no cookie flag, set cookie
  if [[ -z "${TOR_CONTROL_PASSWORD}" ]] && [[ -z "${TOR_CONTROL_COOKIE}" ]]; then
    control_cookie_config
  fi
}

##############################################################################
## Config tor hidden services
##############################################################################
client_authorization_config(){
  ## Convert client hosts string into an array of hosts
  hosts=(${TOR_SERVICE_HOSTS_CLIENTS// / })

  ## Parse through each host
  for host in ${hosts[@]}; do

    ## Convert host string into an array of hostname and clients
    host_details=(${host//=/ })

    ## Set hostname
    service_name=${host_details[0]}
    
    ## Convert clients string into an array of clients
    clients=(${host_details[1]//,/ })
    
    ## Parse over clients array
    for client in ${clients[@]}; do

      ## Use client_auth.sh bash script to create public/private keys
      client_auth.sh -s ${service_name} -c ${client}

    done
  done
}

hidden_services_config(){

  ## Convert service hosts string into an array of hosts
  hosts=(${TOR_SERVICE_HOSTS// / })

  ## Create hidden_services directory and set permission
  mkdir -p /tor/hidden_services && chown -R tor:tor /tor/hidden_services  && chmod 777 /tor/hidden_services

  ## Parse through each host
  for host in ${hosts[@]}; do

    ## Convert host string into an array of hostname and services
    host_details=(${host//=/ })

    ## Set hostname
    service_name=${host_details[0]}
    
    ## Convert services string into an array of services
    services=(${host_details[1]//,/ })
    
    ## Parse over services array
    for service in ${services[@]}; do
      ## Convert service string to array of items
      item=(${service//:/ })

      ## Define hidden service variables
      service_port=${item[0]}
      redirect_host=${item[1]}
      redirect_port=${item[2]}

      ## Write service to line in file
      sed -i "/## Hidden Services/a\HiddenServicePort ${service_port} ${redirect_host}:${redirect_port}" $TOR_CONFIG_FILE
    done    

    ## Write service name to line to file
    ## I go after services because I am inserted after the same line, so we need to do it backwards.
    sed -i "/## Hidden Services/a\ \nHiddenServiceDir /tor/hidden_services/${service_name}" $TOR_CONFIG_FILE
    echo "Added hidden service ${service_hostname} to torrc..."

  done

}


##############################################################################
## Initialise docker image
##############################################################################
init(){
  echo -e "\\n====================================- INITIALISING TOR -===================================="

  ## Copy torrc config file into bind-volume
  cp /tmp/tor/torrc* /tor/
  ## Remove temporary files
  rm -rf /tmp/tor
  echo "Copied torrc into /tor..."

  ## Are we setting up a Tor proxy
  if $TOR_PROXY; then
    echo "Configuring Tor proxy..."
    proxy_config
    echo "Tor proxy configured..."
  else
    sed -i "/SocksPort.*/c\SocksPort 0" $TOR_CONFIG_FILE
    echo "Disabled Tor proxy..."
  fi

  ## Are we setting up control for Tor
  if $TOR_CONTROL; then
    echo "Configuring Tor control..."
    control_config
    echo "Tor control configured..."
  else
    sed -i "/ControlPort.*/c\# ControlPort ${TOR_PROXY_CONTROL_PORT}" $TOR_CONFIG_FILE
  fi

  ## Are we setting up a Tor hidden service
  if $TOR_SERVICE; then
    echo "Configure Tor hidden services..."
    hidden_services_config
    client_authorization_config
    echo "Tor hidden services configured..."
  fi

  # #Are we setting up a Tor relay
  if $TOR_RELAY; then
    echo "Tor relay no supported in the docker image yet!"
  fi
}

##############################################################################
## Main shell script function
##############################################################################
main() {

  ## Initialise container if there is no lock file
  if [[ ! -e $TOR_CONFIG_FILE.lock ]]; then 
    init
    echo "Only run init once. Delete this file to re-init torrc on container start up." > $TOR_CONFIG_FILE.lock
  else
    echo "Torrc already configured. Skipping config templating..."
  fi

  ## Echo config to log if set true
  if $TOR_LOG_CONFIG; then
    echo_config
  fi
}

## Call main function
main

echo -e "\\n====================================- STARTING TOR -===================================="
## Display Tor version & torrc in log
tor --version
echo ''

## Execute Docker file CMD
exec "$@"