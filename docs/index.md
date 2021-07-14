# Docker Tor

## What is Tor

[The Tor Project](https://www.torproject.org/) is a nonprofit organization primarily responsible for maintaining software for the Tor anonymity network. The Tor browser is the most well known piece of software maintained. The Tor Browser uses the onion network to anonymize browsing and the onion network relies on tor relays to achieve this.

## What is this image

This docker image runs a Tor service on an[ Alpine](https://www.alpinelinux.org/) linux base image. The Tor service that can be configure, as single or combination of a:

1. Tor __[Socks5 proxy](proxy.md)__ into the onion network (default)
2. Tor __[hidden service](service.md)__ for onion websites (not supported yet)
3. Tor __[relay](relay.md)__ to support the onion network (not supported yet)

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

Create a docker image with the following docker run command

```bash
docker run -d --name tor -p 9050:9050 -v <your-folder>:/tor barneybuffet/tor:latest
```

#### References

* [The Tor Project](https://gitlab.torproject.org/tpo)
* [hexops/dockerfile - Dockerfile best practices](https://github.com/hexops/dockerfile)
* [Blockstream/bitcoin-images/tor](https://github.com/Blockstream/bitcoin-images/tree/master/tor)
* [RaspiBolt/Privacy](https://stadicus.github.io/RaspiBolt/raspibolt_22_privacy.html)
* [DarkIsDude/tor-server](https://github.com/DarkIsDude/tor-server)
* [dperson/torproxy](https://github.com/dperson/torproxy)
* [cha87de/docker-skeleton](https://github.com/cha87de/docker-skeleton)
* [Container Structure Tests](https://github.com/GoogleContainerTools/container-structure-test)