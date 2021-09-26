#!/usr/bin/env bash

## DEPENDENCIES
# openssl 1.1+, coreutils (Alpine) / basez (Debain)

## REFERENCE
# Bash script template: https://betterdev.blog/minimal-safe-bash-script-template/
# Tor client authorisation: http://xmrhfasfg5suueegrnc4gsgyi2tyclcy5oz7f5drnrodmdtob6t2ioyd.onion/onion-services/advanced/client-auth/index.html
# Key creation adapted from: https://gist.github.com/mtigas/9c2386adf65345be34045dace134140b

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] -p param_value arg1 [arg2...]
Script description here.
Available options:
-h, --help      Print this help and exit
-s, --service   Hidden service name
-c, --client    Hidden service client
-d, --dir       Hidden service directory (optional)
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  service=''
  client=''
  dir='/tor/hidden_services' # Location set in torrc

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    --no-color) NO_COLOR=1 ;;
    -s | --service) # Hidden service name, used in folder path
      service="${2-}"
      shift
      ;;
    -c | --client) # Hideen service authorisation client name
      client="${2-}"
      shift
      ;;
    -d | --dir) # Optional hidden service directory 
      dir="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  # check required params
  [[ -z "${service-}" ]] && die "Missing required parameter: -s | --service"
  [[ -z "${client-}" ]] && die "Missing required parameter: -c | --client"

  return 0
}

parse_params "$@"
setup_colors

####=- START SCRIPT LOGIC -=####

## DIRECTORY/FILE LOCATIONS
auth_dir=${dir}/${service}/authorized_clients
auth_private_dir=${dir}/auth_privates/${service}
hostname_file=${dir}/${service}/hostname 

## GENERATE KEY
openssl genpkey -algorithm x25519 -out /tmp/k1.prv.pem

## CREATE PRIVATE KEY FOR CLIENT
key=$(
  cat /tmp/k1.prv.pem |\
    grep -v " PRIVATE KEY" |\
    base64 -d |\
    tail --bytes=32 |\
    base32 |\
    sed 's/=//g'
)

## CREATE PUBLIC KEY FOR SERVICE
public=$(
  openssl pkey -in /tmp/k1.prv.pem -pubout |\
    grep -v " PUBLIC KEY" |\
    base64 -d |\
    tail --bytes=32 |\
    base32 |\
    sed 's/=//g'
)

## SERVICE ONION ADDRESS
# Default to user finding and pasting onion address
address="<56-char-onion-addr-without-.onion-part>"
# If service has a hostname file, extract onion address without '.onion'
if [ -e ${hostname_file} ]; then
  address=$(
    cat ${dir}/${service}/hostname | sed 's/.onion//g'
  )
fi

## CREATE FOLDERS IF THEY DON'T EXIST
if [ ! -d ${auth_dir} ]; then
  mkdir -p ${auth_dir} && chown -R nonroot:nonroot ${auth_dir} && chmod go+rX,u+rwX ${auth_dir} && chmod go+rX,u+rwX ${dir} && chmod go+rX,u+rwX ${dir}/${service}
fi

if [ ! -d ${auth_private_dir} ]; then
  mkdir -p ${auth_private_dir} && chown -R nonroot:nonroot ${auth_dir}  && chmod go+rX,u+rwX ${auth_private_dir}
fi

## CREATE PUBLIC/PRIVATE KEY FILES
echo "descriptor:x25519:${public}" > ${auth_dir}/${client}.auth
echo "${address}:descriptor:x25519:${key}" > ${auth_private_dir}/${client}.auth_private

## REMOVE GENERATED KEY FROM TMP FOLDER
rm -f /tmp/k1.prv.pem

####=- END SCRIPT LOGIC -=####

# msg "${RED}Read parameters:${NOFORMAT}"
# msg "- service: ${service}"
# msg "- client: ${client}"
# msg "- directory: ${dir}"
# msg "- key: <56-char-onion-addr-without-.onion-part>:descriptor:x25519:${key}"
# msg "- public: descriptor:x25519:${public}"
