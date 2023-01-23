## ALPINE_VER can be overwritten with --build-arg
## Pinned version tag from https://hub.docker.com/_/alpine
ARG ALPINE_VER=latest

########################################################################################
## STAGE ONE - BUILD
########################################################################################
FROM alpine:$ALPINE_VER AS tor-builder

## TOR_VER can be overwritten with --build-arg at build time
## Get latest version from > https://dist.torproject.org/
ARG TOR_VER=0.4.7.11
ARG TORGZ=https://dist.torproject.org/tor-$TOR_VER.tar.gz
#ARG TOR_KEY=0x6AFEE6D49E92B601

## Install tor make requirements
RUN apk --no-cache add --update \
    alpine-sdk \
    gnupg \
    libevent libevent-dev \
    zlib zlib-dev \
    openssl openssl-dev

## Get Tor key file and tar source file
RUN wget $TORGZ
#COPY ./tor-$TOR_VER.tar.gz.sha256sum.asc ./
#COPY ./tor-$TOR_VER.tar.gz ./
## Verify Tor source tarballs asc signatures
## Get signature from key server
#RUN gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys ${TOR_KEY}
## Verify that the checksums file is PGP signed by the release signing key
#RUN gpg --verify tor-${TOR_VER}.tar.gz.sha256sum.asc tor-${TOR_VER}.tar.gz 2>&1 |\
#    grep -q "gpg: Good signature" ||\
#    { echo "Couldn't verify signature!"; exit 1; }
#RUN gpg --verify tor-${TOR_VER}.tar.gz.sha256sum.asc tor-${TOR_VER}.tar.gz 2>&1 |\
#    grep -q "Primary key fingerprint: 2133 BC60 0AB1 33E1 D826  D173 FE43 009C 4607 B1FB" ||\
#    { echo "Couldn't verify Primary key fingerprint!"; exit 1; }

## Make install Tor
RUN tar xfz tor-$TOR_VER.tar.gz &&\
    cd tor-$TOR_VER && \
    ./configure &&\
    make -j 8 install

########################################################################################
## STAGE TWO - RUNNING IMAGE
########################################################################################
FROM alpine:$ALPINE_VER as release

## CREATE NON-ROOT USER FOR SECURITY
RUN addgroup --gid 1001 --system nonroot && \
    adduser  --uid 1000 --system --ingroup nonroot --home /home/nonroot nonroot

## Install Alpine packages
## bind-tools is needed for DNS resolution to work in *some* Docker networks
## Tini allows us to avoid several Docker edge cases, see https://github.com/krallin/tini.
RUN apk --no-cache add --update \
    bash \
    curl \
    libevent \
    tini bind-tools su-exec \
    openssl shadow coreutils \
    python3 py3-pip \
    wget sed \
    && pip install nyx
    

## Bitcoind data directory
ENV DATA_DIR=/tor

## Create tor directories
RUN mkdir -p ${DATA_DIR} && chown -R nonroot:nonroot ${DATA_DIR} && chmod -R go+rX,u+rwX ${DATA_DIR}

## Copy compiled Tor daemon from tor-builder
COPY --from=tor-builder /usr/local/ /usr/local/

## Copy entrypoint shell script for templating torrc
COPY --chown=nonroot:nonroot --chmod=777 entrypoint.sh /usr/local/bin

## Copy client authentication for private/public keys
COPY --chown=nonroot:nonroot --chmod=go+rX,u+rwX client_auth.sh /usr/local/bin

## Copy torrc config and examples to tmp tor. Entrypoint will copy across to bind-
COPY --chown=nonroot:nonroot ./torrc* /tmp/tor/
COPY --chown=nonroot:nonroot ./tor-man-page.txt /tmp/tor/tor-man-page.txt

## Copy nyxrc config into default location
COPY --chown=nonroot:nonroot --chmod=go+rX,u+rwX ./nyxrc /home/tor/.nyx/config

## Docker health check
HEALTHCHECK --interval=60s --timeout=15s --start-period=60s \
            CMD curl -xs --socks5-hostname 127.0.0.1:9050 'https://check.torproject.org' | tac | grep -qm1 Congratulations

## ENV VARIABLES
## Default values
ENV PUID= \
    PGID= \
    TOR_CONFIG_OVERWRITE="false" \
    TOR_LOG_CONFIG="false" \
    TOR_PROXY="true" \
    TOR_PROXY_PORT="9050" \
    TOR_PROXY_SOCKET="false" \
    TOR_PROXY_ACCEPT="accept 127.0.0.1,accept 10.0.0.0/8,accept 172.16.0.0/12,accept 192.168.0.0/16" \
    TOR_CONTROL="false" \
    TOR_CONTROL_PORT="9051" \
    TOR_CONTROL_SOCKET="false" \
    TOR_CONTROL_PASSWORD= \
    TOR_CONTROL_COOKIE="true" \
    TOR_SERVICE="false" \
    TOR_SERVICE_HOSTS="nextcloud=80:192.168.0.3:80" \
    TOR_SERVICE_HOSTS_CLIENTS="nextcloud=alice,bob" \
    TOR_RELAY="false"

## Label the docker image
LABEL maintainer="Sidorin Konstantin <Deathmond1987@gmail.com>"
LABEL name="Tor network client (daemon) with custom bridges"
LABEL version=$TOR_VER
LABEL description="A docker image for tor with bridge finder"
LABEL license="GNU"
LABEL url="https://www.torproject.org"
LABEL vcs-url="https://github.com/deathmond1987/docker-tor/"  

VOLUME [ "$DATA_DIR" ]
WORKDIR ${DATA_DIR}
EXPOSE 9050/tcp 9051/tcp
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]
CMD ["tor", "-f", "/tor/torrc"]

WORKDIR /tmp/tor
RUN wget https://github.com/ValdikSS/tor-relay-scanner/releases/download/0.0.7/tor-relay-scanner-0.0.7.pyz
COPY torrc /tmp/tor/
