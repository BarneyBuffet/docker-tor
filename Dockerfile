# ALPINE_VER can be overwritten on with --build-arg
ARG ALPINE_VER=3.14

# Replace latest with a pinned version tag from https://hub.docker.com/_/alpine
FROM alpine:$ALPINE_VER AS tor-builder

# Get latest version from > https://dist.torproject.org/
# Can be overwritten on with --build-arg at build time
ARG TOR_VER=0.4.6.6
ARG TORGZ=https://dist.torproject.org/tor-$TOR_VER.tar.gz
# http://jqyzxhjk6psc6ul5jnfwloamhtyh7si74b4743k2qgpskwwxrzhsxmad.onion/include/keys.txt
ARG TOR_KEY=0x6AFEE6D49E92B601

# Install tor make requirements
RUN apk --no-cache add --update \
    alpine-sdk \
    gnupg \
    libevent libevent-dev \
    zlib zlib-dev \
    openssl openssl-dev

# Get Tor key file and tar file
RUN wget $TORGZ.asc &&\
    wget $TORGZ

############################################
## Verify Tor source tarballs asc signatures
## Get signature from key server
RUN gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys ${TOR_KEY}
# Verify that the checksums file is PGP signed by the release signing key
RUN gpg --verify tor-${TOR_VER}.tar.gz.asc tor-${TOR_VER}.tar.gz 2>&1 |\
    grep -q "gpg: Good signature" ||\
    { echo "Couldn't verify signature!"; exit 1; }
RUN gpg --verify tor-${TOR_VER}.tar.gz.asc tor-${TOR_VER}.tar.gz 2>&1 |\
    grep -q "Primary key fingerprint: 2133 BC60 0AB1 33E1 D826  D173 FE43 009C 4607 B1FB" ||\
    { echo "Couldn't verify Primary key fingerprint!"; exit 1; }

# Build tor
RUN tar xfz tor-$TOR_VER.tar.gz &&\
    cd tor-$TOR_VER && \
    ./configure &&\
    make install

########################################################################################
FROM alpine:$ALPINE_VER

# Non-root user for security purposes.
RUN addgroup --gid 10001 --system tor && \
    adduser  --uid 10000 --system --ingroup tor --home /home/tor tor

# Install Alpine packages
# bind-tools is needed for DNS resolution to work in *some* Docker networks
# Tini allows us to avoid several Docker edge cases, see https://github.com/krallin/tini.
RUN apk --no-cache add --update \
    bash \
    curl \
    libevent \
    tini \
    bind-tools \
    openssl \
    coreutils

# Create tor directories
RUN mkdir -p /var/run/tor && chown -R tor:tor /var/run/tor && chmod 2700 /var/run/tor && \
    mkdir -p /tor && chown -R tor:tor /tor  && chmod 777 /tor

# Copy compiled Tor daemon from tor-builder
COPY --from=tor-builder /usr/local/ /usr/local/

# Copy entrypoint shell script for templating torrc
COPY --chown=tor:tor --chmod=+x entrypoint.sh /usr/local/bin
# Copy client authentication for private/public keys
COPY --chown=tor:tor --chmod=+x client_auth.sh /usr/local/bin

# Copy torrc and examples to tmp tor. Entrypoint will copy across to bind-volume
COPY --chown=tor:tor ./torrc* /tmp/tor/

# Docker health check
HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
            CMD curl -sx localhost:8118 'https://check.torproject.org/' | \
            grep -qm1 Congratulations

# Available environmental variables
ENV TOR_LOG_CONFIG="false" \
    TOR_PROXY="true" \
    TOR_PROXY_PORT="9050" \
    TOR_PROXY_ACCEPT="accept 127.0.0.1,accept 10.0.0.0/8,accept 172.16.0.0/12,accept 192.168.0.0/16" \
    TOR_CONTROl="false" \
    TOR_CONTROL_PORT="9051" \
    TOR_CONTROL_PASSWORD="***-password-***" \
    TOR_CONTROL_COOKIE="true" \
    TOR_SERVICE="false" \
    TOR_SERVICE_HOSTS="nextcloud=80:192.168.0.3:80" \
    TOR_SERVICE_HOSTS_CLIENTS="nextcloud=alice,bob"\
    TOR_RELAY="false"


# Label the docker image
LABEL maintainer="Barney Buffet <BarneyBuffet@tutanota.com>"
LABEL name="Tor network client (daemon)"
LABEL version=$TOR_VER
LABEL description="A docker image for tor"
LABEL license="GNU"
LABEL url="https://www.torproject.org"
LABEL vcs-url="https://github.com/BarneyBuffet"  

USER tor
WORKDIR /tor
EXPOSE 9050/tcp 9051/tcp
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]
CMD ["tor", "-f", "/tor/torrc"]

# https://dockerlabs.collabnix.com/docker/cheatsheet/