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

### Socks5 Binding and Port

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

### Socks5 Accept Policy

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
  -e TOR_PROXY_ACCEPT='accpet 192.168.0.11' \
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
