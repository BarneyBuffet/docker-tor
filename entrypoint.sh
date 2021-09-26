#!/bin/bash
set -eo pipefail

# Set config file variable
TOR_CONFIG_FILE=${DATA_DIR}/torrc
SERVICE_DIR=${DATA_DIR}/hidden_services

##############################################################################
## Display TOR torrc config in log
##############################################################################
echo_config(){
  echo -e "\\n====================================- START ${TOR_CONFIG_FILE} -===================================="
  cat $TOR_CONFIG_FILE
  echo -e "=====================================- END ${TOR_CONFIG_FILE} -=====================================\\n"
}

##############################################################################
## Map container runtime PUID & PGID
##############################################################################
map_user(){
  ## https://github.com/magenta-aps/docker_user_mapping/blob/master/user-mapping.sh
  ## https://github.com/linuxserver/docker-baseimage-alpine/blob/3eb7146a55b7bff547905e0d3f71a26036448ae6/root/etc/cont-init.d/10-adduser
  ## https://github.com/haugene/docker-transmission-openvpn/blob/master/transmission/userSetup.sh

  ## Set puid & pgid to run container, fallback to defaults
  PUID=${PUID:-1000}
  PGID=${PGID:-1001}

  ## If uid or gid is different to existing modify nonroot user to suit
  if [ ! "$(id -u nonroot)" -eq "$PUID" ]; then usermod -o -u "$PUID" nonroot ; fi
  if [ ! "$(id -g nonroot)" -eq "$PGID" ]; then groupmod -o -g "$PGID" nonroot ; fi
  echo "Tor set to run as nonroot with uid:$(id -u nonroot) & gid:$(id -g nonroot)"

  ## Make sure volumes directories match nonroot
  chown -R nonroot:nonroot \
    ${DATA_DIR}
  echo "Enforced ownership of ${DATA_DIR} to nonroot:nonroot"
  
  ## Make sure volume permissions are correct
  chmod -R go=rX,u=rwX \
    ${DATA_DIR}
  echo "Enforced permissions for ${DATA_DIR} to go=rX & u=rwX"

  ## Export to the rest of the bash script
  export PUID
  export PGID

}

##############################################################################
## Config Tor as a Socks5 proxy
##############################################################################
proxy_config(){

  ## Torrc default has proxy set to '0' so we need to have a default setting
  if [[ -n "${TOR_PROXY_PORT}" ]]; then
    sed -i "/SocksPort 0/c\SocksPort ${TOR_PROXY_PORT}" $TOR_CONFIG_FILE
    echo "Updated proxy binding and port..."
  fi

  if $TOR_PROXY_SOCKET; then
    ## Needs to be WorldWritable for bind mounts
    sed -i "/# SocksPort unix:.*/c\SocksPort unix:/tor/socks5.socket WorldWritable RelaxDirModeCheck" $TOR_CONFIG_FILE
    echo "Updated proxy socket..."
  fi

  ## IP or IP ranges accepted by the proxy. Everything else is rejected
  if [[ -n "${TOR_PROXY_ACCEPT}" ]]; then
    sed -i "/SocksPolicy accept/c\SocksPolicy ${TOR_PROXY_ACCEPT}" $TOR_CONFIG_FILE
    echo "Updated proxy accept policy..."
  fi
}

##############################################################################
## Config Tor Control
##############################################################################
control_config(){

  ## If we have a control port variable set it
  if [[ -n "${TOR_CONTROL_PORT}" ]]; then
    sed -i "/# ControlPort.*/c\ControlPort ${TOR_CONTROL_PORT}" $TOR_CONFIG_FILE
    echo "Control port set to ${TOR_CONTROL_PORT} ..."
  fi

  ## Set control socket if set true
  if $TOR_CONTROL_SOCKET; then
    ## Needs to be WorldWritable for bind mounts
    sed -i "/# ControlSocket unix:.*/c\ControlSocket unix:/tor/control.socket WorldWritable RelaxDirModeCheck" $TOR_CONFIG_FILE
    echo "Control socket set ..."
  fi

  ## If we have a password hash it and set
  if [[ -n "${TOR_CONTROL_PASSWORD}" ]]; then
    HASHED_PASSWORD=$(tor --hash-password $TOR_CONTROL_PASSWORD)
    sed -i "/# HashedControlPassword.*/c\HashedControlPassword $HASHED_PASSWORD" $TOR_CONFIG_FILE
    echo "Opened control with password ..."
  fi

  ## If cookie is true then set 1
  if $TOR_CONTROL_COOKIE; then
    ## Set control cookie true in config
    sed -i "/# CookieAuthentication.*/c\CookieAuthentication 1" $TOR_CONFIG_FILE
    echo "Opened control with authentication true ..."
  fi

  ## If we don't have a password and no cookie flag, set cookie by default
  if [[ -z "${TOR_CONTROL_PASSWORD}" ]] && [[ ! $TOR_CONTROL_COOKIE ]]; then
    ## Set control cookie true in config
    sed -i "/# CookieAuthentication.*/c\CookieAuthentication 1" $TOR_CONFIG_FILE
    echo "Password or cookie not set. Defaulting to control with cookie authentication ..."
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
## Copy config files from tmp into bind volume
##############################################################################
copy_files(){
  ## Copy torrc config file into bind-volume
  cp /tmp/tor/torrc* ${DATA_DIR}
  cp /tmp/tor/tor-man-page.txt ${DATA_DIR}
  ## We are not deleting because we need the config if we are overwriting
  echo "Copied torrc into /tor..."
}

##############################################################################
## Link config to default location
##############################################################################
link_config(){
  ## If we have a cookie, symbolic link to default for nyx
  ## TODO: nyx should be its own container
  if [[ ! -f /tor/control_auth_cookie  ]] && [[ -f /home/tor/.tor/control_auth_cookie  ]]; then 
    mkdir -p /home/tor/.tor
    ln -s /tor/control_auth_cookie /home/tor/.tor/control_auth_cookie
    echo "Symbolic link authorisation cookie..."
  fi
}

##############################################################################
## Initialise docker image
##############################################################################
init(){
  echo -e "\\n====================================- INITIALISING TOR -===================================="

  copy_files

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
## Main function
##############################################################################
main() {

  ## Initialise container if there is no lock file or we are overwriting
  if [[ ! -e $TOR_CONFIG_FILE.lock ]] || $TOR_CONFIG_OVERWRITE; then 
    init
    echo "Only run init once. Delete this file to re-init torrc on container start up." > $TOR_CONFIG_FILE.lock
  else
    echo "Torrc already configured. Skipping config templating..."
  fi

  map_user
  link_config

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

## Execute dockerfile CMD as nonroot alternate gosu
su-exec "${PUID}:${PGID}" "$@"