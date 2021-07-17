# Tor Proxy

## What is a proxy

A [proxy](https://en.wikipedia.org/wiki/Proxy_server) server acts as an intermediary between clients (you) and servers that provide websites and services. A proxy server thus functions on behalf of the client when requesting services, potentially masking the true origin of the request to the resource server.

Tor core implements a Socks5 proxy. SOCKS5 is the most recently optimized version of Socket secure (or [SOCKS](https://en.wikipedia.org/wiki/SOCKS)) proxy.

By default this docker image will configure and run a Tor Socks5 proxy. The proxy can be disabled by setting `-e TOR_PROXY=false` when running the docker image.

## Start a Tor Proxy

To start a Tor proxy instance with this image run the following docker command:

```bash
docker run -d --name tor -p 9050:9050/tcp barneybuffet/tor:latest
```

By default the image will:

* Set socks5 proxy port to `9050`
* Set socks5 proxy port binding to all ip address. i.e. `0.0.0.0`
* Restrict socks5 proxy access to [RFC1918](https://datatracker.ietf.org/doc/html/rfc1918#section-3) local addresses, and reject all others ip address

These defaults can be configured via docker environmental variables (options) discussed below.

## Tor Proxy Options

The following environmental (configuration) options are available when configuring the Socks5 proxy:

### Binding and Port

This image configures by default a proxy binding of all ips through `0.0.0.0` and a port of `9050` (the tor default port). Access to the proxy is restricted to RFC1918](https://datatracker.ietf.org/doc/html/rfc1918#section-3) local network IP addresses through accept policies discussed below. The socks5 binding and port will be set to `SocksPort 0` if `TOR_PROXY=false`, disabling the tor proxy client.

Default configuration:

```bash
SocksPort 0.0.0.0:9050
```

The binding and port can be configure using `TOR_PROXY_PORT=<address>:<port>` with `TOR_PROXY=true`.

The below env options will bind the proxy to localhost (i.e. 127.0.0.1) on port 9150. This might be useful when using docker-compose and networking services together.

```bash
docker run -d --name tor \
  -e TOR_PROXY=true \
  -e TOR_PROXY_PORT=localhost:9150 \
  -p 9150:9150/tcp \
  barneybuffet/tor:latest
```

Bind to ip 192.168.0.1 on port 9100:

```bash
docker run -d --name tor \
  -e TOR_PROXY=true \
  -e TOR_PROXY_PORT=192.168.0.1:9100 \
  -p 9100:9100/tcp \
  barneybuffet/tor:latest
```

### Accept Policy

Tor will allow/deny SOCKS requests based on IP address. By default this image will accept the localhost and all connections from [RFC1918](https://datatracker.ietf.org/doc/html/rfc1918#section-3) local network IP addresses. All other IP address will be rejected.

The `SocksPolicy reject *` is not configurable by this docker image environmental flags.

Default configuration:

```bash
## Accept localhost and RFC1918 networks, reject all others
SocksPolicy accept 127.0.0.1,accept 10.0.0.0/8,accept 172.16.0.0/12,accept 192.168.0.0/16
SocksPolicy reject *
```

The accept socks policy can be configure using `TOR_PROXY_ACCEPT=accept <ip or IP Subnet>,accept <ip or IP Subnet>,...` with `TOR_PROXY=true`.

Allow only 192.168.0.11 to use the proxy:

```bash
docker run -d --name tor \
  -e TOR_PROXY=true \
  -e TOR_PROXY_ACCEPT='accept 192.168.0.11' \
  -p 9050:9050/tcp \
  barneybuffet/tor:latest
```

Will configure to

```bash
## Accept localhost and RFC1918 networks, reject all others
SocksPolicy accept 192.168.0.11
SocksPolicy reject *
```

Allow only 192.168.1.0 [subnet](http://www.steves-internet-guide.com/subnetting-subnet-masks-explained/) IPs to use the proxy:

```bash
docker run -d --name tor \
  -e TOR_PROXY=true \
  -e TOR_PROXY_ACCEPT="accept localhost,accept 192.168.1.0/24" \
  -p 9050:9050/tcp \
  barneybuffet/tor:latest
```

Will configure to

```bash
## Accept localhost and RFC1918 networks, reject all others
SocksPolicy accept localhost,accept 192.168.1.0/24 
SocksPolicy reject *
```

## Tor Control Port

The [Control Port](https://gitweb.torproject.org/torspec.git/tree/control-spec.txt) is used to control communication with the Tor daemon. Once the Control Port is open it is important that a form of authentication is set. By default this docker image will default cookie authentication if password is not passed in. The authentication cookie is stored at `/tor/control.authcookie` and can be accessed if you mount the `/tor` directory.

Default configuration.

```bash
## The port on which Tor will listen for local connections from Tor
## controller applications, as documented in control-spec.txt.
## https://gitweb.torproject.org/torspec.git/tree/control-spec.txt
# ControlPort 9051

## If you enable the controlport, be sure to enable one of these
## authentication methods, to prevent attackers from accessing it.
# HashedControlPassword 16:872860B76453A77D60CA2BB8C1A7042072093276A3D701AD684053EC4C
# CookieAuthentication 1
# CookieAuthFileGroupReadable 1
```

To open up the control port a port number needs to be set. Below will open a control port on 9051 and by default set authentication cookie.

```bash
docker run -d --name tor \
  -e TOR_PROXY_CONTROL_PORT='9051' \
  -p 9050:9050/tcp \
  -p 9051:9051/tcp \
  barneybuffet/tor:latest
```

The docker image will create the following configuration within `/tor/torrc`

```bash
## The port on which Tor will listen for local connections from Tor
## controller applications, as documented in control-spec.txt.
## https://gitweb.torproject.org/torspec.git/tree/control-spec.txt
ControlPort 9051

## If you enable the controlport, be sure to enable one of these
## authentication methods, to prevent attackers from accessing it.
# HashedControlPassword 16:872860B76453A77D60CA2BB8C1A7042072093276A3D701AD684053EC4C
CookieAuthentication 1
CookieAuthFileGroupReadable 1
```

If you would prefer to set a password for the control port this can be done with `TOR_PROXY_CONTROL_PASSWORD='<my secret password'`

```bash
docker run -d --name tor \
  -e TOR_PROXY_CONTROL_PORT='9051' \
  -e TOR_PROXY_CONTROL_PASSWORD='password' \
  -p 9050:9050/tcp \
  -p 9051:9051/tcp \
  barneybuffet/tor:latest
```

The docker image will create the following configuration within `/tor/torrc`

```bash
## The port on which Tor will listen for local connections from Tor
## controller applications, as documented in control-spec.txt.
## https://gitweb.torproject.org/torspec.git/tree/control-spec.txt
ControlPort 9051

## If you enable the controlport, be sure to enable one of these
## authentication methods, to prevent attackers from accessing it.
HashedControlPassword 16:872860B76453A77D60CA2BB8C1A7042072093276A3D701AD684053EC4C
#CookieAuthentication 1
#CookieAuthFileGroupReadable 1
```

## Test Tor is working

Once the docker container is running the tor connection can be tested by opening a terminal within the container and using the below commands

Check the container ip address against your internet ip address

```bash
curl --socks5 localhost:9050 --socks5-hostname localhost:9050 https://ipinfo.io/ip
```

Confirm connection to the Tor network

```bash
curl --socks5 localhost:9050 --socks5-hostname localhost:9050 -s https://check.torproject.org/ | cat | grep -m 1 Congratulations | xargs
```

The connection to the container can be check using the same commands.
