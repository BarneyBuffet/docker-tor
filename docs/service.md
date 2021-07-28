# Location Hidden Service (.onion)

A hidden service is a site you visit or a service that uses Tor technology to stay secure and, if the owner wishes, anonymous. The terms "hidden services" and "onion services" are interchangeably.

By default this image will not enable any hidden services. To enable hidden services the `-e TOR_SERVICE=true` flag is needed along wih a list of hosts in `-e TOR_SERVICE_HOSTS='<hostname>=<wan port>:<redirect IP>:<redirect port>,...'`. Multiple services can be configure for a host.

It is generally good practice to create seperate Tor deamons for each hostname, but is not required.

## Start a Hidden Service

To start a Tor hidden service with this image run the following docker command:

```bash
docker run -d --name tor -e TOR_SERVICE=true -e TOR_SERVICE_HOSTS='bitcoin=443:192.168.1.7:80,8443:192.168.1.5:443' -e TOR_SERVICE_HOSTS_CLIENTS='bitcoin=barney' -p 9050:9050/tcp barneybuffet/tor:latest`
```

The image will:

* Tell Tor to create a hidden service in `/tor/hidden_services/<hostname>`
* Configure Tor to accept onion requests on a given port and redirect to an IP address and port
* Create an authroized client private/public key pair

The onion address can be found in `/tor/hidden_services/<hostname>/hostname`
The private key can be found in `/tor/hidden_services/auth_privates/<hostname>/<client>.auth_private`

## Hidden Services Options

The `TOR_SERVICE_HOSTS` flag uses the following configuration within the string.

```bash
-e TOR_SERVICE_HOSTS='<hostname>=<wan port>:<redirect IP>:<redirect port>,<wan port>:<redirect IP>:<redirect port>,... <hostname>=<wan port>:<redirect IP>:<redirect port>,<wan port>:<redirect IP>:<redirect port>,...
```

Multiple hosts can be configure with a space seperated list. And multiple services can be configure for each service with comma seperated array.

```bash
-e TOR_SERVICE_HOSTS='<hostname>=<service 1>,<service 2>,... <hostname 2>=<service 1>,<service 2>,<service 3> ...
```

Each service is configured via : seperated list and requires a wan, ip address and port

| Option            | Description                                                 |
|:------------------|:------------------------------------------------------------|
| `<hostname>`      | The hidden service holder                                   |
| `<wan port>`      | The incoming port the onion service will listen on          |
| `<redirect ip>`   | The ip address to redirect the onion request to             |
| `<redictio port>` | The port on the ip address to redirect the onion request to |

## Hidden Services Clients

Client authorization is a method to make an onion service private and authenticated. It requires Tor clients to provide an authentication credential in order to connect to the onion service. The service side is configured with a public key and the client can only access it with a private key.

Note: Once you have configured client authorization, anyone with the address will not be able to access it from this point on. If no authorization is configured, the service will be accessible to anyone with the onion address.

This docker image has a bash script that generates public/private key pairs. To generate key during the first container start up you can set the `-e TOR_SERVICE_HOSTS_CLIENTS=hostname=client-1,client-2,...`.

The bash script will generate a private and matching public key. The keys are put in the following directories:

* Public Key: `/tor/hidden_services/<hostname>/authorized_clients/<client>.auth`
* Private Key: `/tor/auth_privates/<hostname>/<client>.auth_private`

A new client private/public key can be generated at any time by opening a terminal in the docker container and running the bash script.

```bash
client_auth.sh --service <hostname> --client alice
```

To copy the private key for use with your Tor browser in osx open a terminal in the `/tor/hidden_services/auth_privates/<hostname>/` binded port and use the following command.

```bash
cp <client>.auth_private ~/Library/Application Support/TorBrowser-Data/Tor/
```

#### References

* [Best Practices for Hosting Onion Services](https://riseup.net/en/security/network-security/tor/onionservices-best-practices)
* [Tor Hidden Services ](https://www.linuxjournal.com/content/tor-hidden-services)
* [Set up Your Onion Service](http://xmrhfasfg5suueegrnc4gsgyi2tyclcy5oz7f5drnrodmdtob6t2ioyd.onion/onion-services/setup/index.html)
* [Minimal safe Bash script template](https://betterdev.blog/minimal-safe-bash-script-template/)
* [Client Authorization](http://xmrhfasfg5suueegrnc4gsgyi2tyclcy5oz7f5drnrodmdtob6t2ioyd.onion/onion-services/advanced/client-auth/index.html)
* [mtigas/onion-svc-v3-client-auth.sh](https://gist.github.com/mtigas/9c2386adf65345be34045dace134140b)
