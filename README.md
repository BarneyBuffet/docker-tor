# Docker Tor

## What is Tor

[The Tor Project](https://www.torproject.org/) is a nonprofit organization primarily responsible for maintaining software for the Tor anonymity network. The Tor browser is the most well known piece of software maintained. The Tor Browser uses the onion network to anonymize browsing and the onion network relies on tor relays to achieve this.

## What is this image

This docker image runs a Tor service on an[ Alpine](https://www.alpinelinux.org/) linux base image. The Tor service that can be configure, as single or combination of a:

1. Tor __Socks5 proxy__ into the onion network (default)
2. Tor __hidden service__ for onion websites (not supported yet)
3. Tor __relay__ to support the onion network (not supported yet)

The docker image:

* Starts with an Alpine linux base image
* Downloads the Tor source code tarballs and associated signature file
* Verifies the Tor source tarballs against [Roger Dingledine: 0xEB5A896A28988BF5](https://2019.www.torproject.org/include/keys.txt) key
* Compiles Tor from source
* Templates out the Tor config file [torrc](https://www.mankier.com/1/tor)
* Starts the tor service

During container creation the container will log creation of the config file, the templated config file and once created will log any Tor notifications.

This image exposes port `9050/tcp` and `9051/tcp`.

Data can be persisted and config manual edited by mounting the `/tor`

## How to use this image

Create a docker image with the following docker-compose.yml file

```bash
---
version: "3.9"

services:
  tor:
    container_name: tor
    image: barneybuffet/tor:latest
    environment:
      TOR_PROXY: 'true'
      TOR_PROXY_PORT: '9050'
      TOR_PROXY_ACCEPT: 'accept 127.0.0.1,accept 10.0.0.0/8,accept 172.16.0.0/12,accept 192.168.0.0/16'
      TOR_PROXY_CONTROL_PORT: '9051'
      TOR_PROXY_CONTROL_PASSWORD: 'password'
      TOR_PROXY_CONTROL_COOKIE: 'true'
    volumes:
      - ${PWD}:/tor/
    ports:
      - "9050:9050/tcp"
      - "9051:9051/tcp"
    restart: unless-stopped
```

## References

* [Docker Tor - Git Repository](https://github.com/BarneyBuffet/docker-tor)
* [Docker Tor - Documentation](https://barneybuffet.github.io/docker-tor/)

### Start Visual Studio code with Tor Proxy

```bash
code --proxy-server="Socks5=tor.home:9050"
```