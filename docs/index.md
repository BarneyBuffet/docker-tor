# Docker Tor

## What is Tor

[The Tor Project](https://www.torproject.org/) is a nonprofit organization primarily responsible for maintaining software for the Tor anonymity network. The Tor browser is the most well known piece of software maintained. The Tor Browser uses the onion network to anonymize browsing and the onion network relies on tor relays to achieve this.

Tor can't help you if you use it wrong! Learn how to be safe at [https://www.torproject.org/download/download#warning](https://www.torproject.org/download/download#warning)

## What is this image

This docker image runs a Tor service on an[ Alpine](https://www.alpinelinux.org/) linux base image. The Tor service that can be configure, as single or combination of a:

1. Tor __[Socks5 proxy](proxy.md)__ into the onion network (default)
2. Tor __[hidden service](service.md)__ for onion websites (not supported yet)
3. Tor __[relay](relay.md)__ to support the onion network (not supported yet)

This docker image will:

* Start with an Alpine linux base image
* Download the Tor source code tarballs and associated signature file
* Verify the Tor source tarballs against [Roger Dingledine: 0xEB5A896A28988BF5](https://2019.www.torproject.org/include/keys.txt) key
* Compile Tor from source
* Templates out the Tor config file [torrc](https://www.mankier.com/1/tor) _(this step is skipped if torrc.lock file exists in the `/tor` directory)_
* Set a torrc.lock file to persist config file
* Starts the tor service

During container creation the container will log creation of the config file, the templated config file and once created will log any Tor notifications.

This image exposes port `9050/tcp` and `9051/tcp`.

Data can be persisted and `torrc` config manually edited by mounting the `/tor` directory.

## How to use this image

Create a docker image with the following docker run command

```bash
docker run -d --name tor -p 9050:9050 -v <your-folder>:/tor barneybuffet/tor:latest
```

Docker compose file:

```bash
---
version: "3.9"

services:
  tor:
    container_name: tor
    image: barneybuffet/tor:latest
    environment:
      TOR_LOG_CONFIG:'false'
      TOR_PROXY: 'true'
      TOR_PROXY_PORT: '9050'
      TOR_PROXY_ACCEPT: 'accept 127.0.0.1,accept 10.0.0.0/8,accept 172.16.0.0/12,accept 192.168.0.0/16'
      TOR_CONTROL: 'false'
      TOR_CONTROL_PORT: '9051'
      TOR_CONTROL_PASSWORD: 'password'
      TOR_CONTROL_COOKIE: 'true'
      TOR_SERVICE: 'false'
      TOR_SERVICE_HOSTS='bitcoin=80:192.168.0.3:80'
      TOR_SERVICE_HOSTS_CLIENTS='bitcoin=alice'
      TOR_RELAY: 'false'

    volumes:
      - tor:/tor/
      ports:
      - "9050:9050/tcp"
    restart: unless-stopped
```

## Volume

This image sets the Tor data directory to `/tor`, including the authorisation cookie. To persist Tor data and config you can mount the `/tor` directory from your image.

If the Tor configuration you are after isn't set by the container environmental variables you can modify the `/tor/torrc` for your custom configuration. The `torrc` file will persist while the `/tor/torrc.lock` file is present.

## Available Environmental Flags

Below is a list of available environmental flags that can be set during container creation.

| Flag | Choices/Default | Comments |
|:-----|:----------------|:---------|
| TOR_LOG_CONFIG | true/__false__ | Should the tor config file `torrc` be echo'd to the log. This can be helpful when setting up a new Tor daemon |
| TOR_PROXY      | __true__/false | Set up the Tor daemon as a Socks5 proxy |
| TOR_PROXY_PORT | string (9050) | What port the Tor daemon should listen to for proxy requests |
| TOR_PROXY_SOCKET| true/__false__ | Create a unix socket for the proxy in the data folder |
| TOR_PROXY_ACCEPT | Accept localhost and RFC1918 networks, reject all others | What IP addresses are allowed to route through the proxy |
| TOR_CONTROL | true/__false__ | Should the Tor control be enabled |
| TOR_CONTROL_PORT | string (9051) | What port should the Tor daemon be controlled on. If enabled cookie authentication is also enabled by default |
| TOR_CONTROL_SOCKET | true/__false__ | Create a unix socket for the Tor control |
| TOR_CONTROL_PASSWORD | string | Authentication password for using the Tor control port |
| TOR_CONTROL_COOKIE | __true__/false | Cookie to confirm when Tor control port request sent |
| TOR_SERVICE | true/__false__ | Set up the Tor daemon with hidden services |
| TOR_SERVICE_HOSTS | hostname=wan-port:redict-ip:rediect-port | Tor hidden service configuration |
| TOR_SERVICE_HOSTS_CLIENTS | hostname:client-1,client-2,... | Authorised clients for hostname |
| TOR_RELAY | true/__false__ | ** NOT IMPLEMENTED YET ** |

### References

* [The Tor Project](https://gitlab.torproject.org/tpo)
* [How to install Tor](http://xmrhfasfg5suueegrnc4gsgyi2tyclcy5oz7f5drnrodmdtob6t2ioyd.onion/onion-services/setup/install/index.html)
* [hexops/dockerfile - Dockerfile best practices](https://github.com/hexops/dockerfile)
* [Blockstream/bitcoin-images/tor](https://github.com/Blockstream/bitcoin-images/tree/master/tor)
* [RaspiBolt/Privacy](https://stadicus.github.io/RaspiBolt/raspibolt_22_privacy.html)
* [DarkIsDude/tor-server](https://github.com/DarkIsDude/tor-server)
* [dperson/torproxy](https://github.com/dperson/torproxy)
* [cha87de/docker-skeleton](https://github.com/cha87de/docker-skeleton)
* [Container Structure Tests](https://github.com/GoogleContainerTools/container-structure-test)