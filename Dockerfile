# Replace latest with a pinned version tag from https://hub.docker.com/_/alpine
FROM alpine:3.14 AS tor-builder

# Get latest version from > https://dist.torproject.org/
ARG TOR_VER=0.4.6.6 
ARG TORGZ=https://dist.torproject.org/tor-$TOR_VER.tar.gz

# Install tor make requirements
RUN apk --no-cache add --update \
    alpine-sdk gnupg libevent libevent-dev zlib zlib-dev openssl openssl-dev

# Get Tor key file and tar file
RUN wget $TORGZ.asc &&\
    wget $TORGZ

# Verify Tor source tarballs asc signatures
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys 0xEB5A896A28988BF5 && \
    gpg --verify tor-$TOR_VER.tar.gz.asc || { echo "Couldn't verify sig"; exit; }

# Build tor
RUN tar xfz tor-$TOR_VER.tar.gz &&\
    cd tor-$TOR_VER && \
    ./configure &&\
    make install

FROM alpine:3.14

LABEL maintainer="Barney Buffet <BarneyBuffet@tutanota.com>"
LABEL name="tor"
LABEL version=$TOR_VER
LABEL description="A docker image for tor"

# Non-root user for security purposes.
#
# UIDs below 10,000 are a security risk, as a container breakout could result
# in the container being ran as a more privileged user on the host kernel with
# the same UID.
#
# Static GID/UID is also useful for chown'ing files outside the container where
# such a user does not exist.
RUN addgroup --gid 10001 --system tor && \
    adduser  --uid 10000 --system --ingroup tor --home /home/tor tor

# Install Alpine packages
# bind-tools is needed for DNS resolution to work in *some* Docker networks
# Tini allows us to avoid several Docker edge cases, see https://github.com/krallin/tini.
RUN apk --no-cache add --update \
    bash curl libevent tini bind-tools

# Create tor directories
RUN mkdir -p /var/run/tor && chown -R tor:tor /var/run/tor && chmod 2700 /var/run/tor && \
    mkdir -p /tor && chown -R tor:tor /tor  && chmod 2700 /tor

# Copy compiled tor from tor-builder
COPY --from=tor-builder /usr/local/ /usr/local/

# Copy torrc
COPY --chown=tor:tor ./torrc /tor/torrc
COPY --chown=tor:tor ./torrc.example /tor/torrc.example
COPY --chown=tor:tor --chmod=+x ./entrypoint.sh /entrypoint.sh

USER tor
EXPOSE 9050/tcp 9051/tcp

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
            CMD curl -sx localhost:8118 'https://check.torproject.org/' | \
            grep -qm1 Congratulations

VOLUME ["/tor"]

ENV TOR_PROXY=true\
    TOR_SERVICE=false\
    TOR_RELAY=false

# Tini entry point for container init
# ENTRYPOINT ["/sbin/tini", "--", "tor"]
ENTRYPOINT ["/sbin/tini", "--", "/bin/sh", "/entrypoint.sh"]

# Default arguments for your app (remove if you have none):
# CMD ["-f", "/home/tor/tor/torrc"]
CMD ["tor", "-f", "/tor/torrc"]