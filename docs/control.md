# Tor Control

The [Control Port](https://gitweb.torproject.org/torspec.git/tree/control-spec.txt) is used to control communication with the Tor daemon. Once the Control Port is open it is important that a form of authentication is set. By default this docker image will default cookie authentication if password is not passed in. The authentication cookie is stored at `/tor/control.authcookie` and can be accessed if you mount the `/tor` directory.

## Enable Tor Control

This Docker image will enable Tor control with the flat `-e TOR_CONTROl="true"`.

```bash
docker run -d --name tor \
  -e TOR_CONTROL='true' \
  -p 9050:9050/tcp \
  -p 9051:9051/tcp \
  barneybuffet/tor:latest
```

The default control configuration once enabled for this image is:

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

If you would prefer to set a password for the control port this can be done with `TOR_PROXY_CONTROL_PASSWORD='<my secret password>'`

```bash
docker run -d --name tor \
  -e TOR_CONTROL='true' \
  -e TOR_CONTROL_PORT='9051'
  -e TOR_CONTROL_PASSWORD='password' \
  -e TOR_CONTROL_COOKIE='false' \
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

