# Location Hidden Service (.onion)

A hidden service is a site you visit or a service that uses Tor technology to stay secure and, if the owner wishes, anonymous. The terms "hidden services" and "onion services" are interchangeably.

By default this image will not enable any hidden services. To enable hidden services the `-e TOR_SERVICE=true` flag is needed along wih a list of hosts in `-e TOR_SERVICE_HOSTS='<hostname>=<wan port>:<redirect IP>:<redirect port>,...'`.

## Start a Hidden Service

To start a Tor hidden service with this image run the following docker command:

```bash
docker run -d --name tor -e TOR_SERVICE=true -e TOR_SERVICE_HOSTS='bitcoin=443:192.168.1.7:80,8443:192.168.1.5:443` -p 9050:9050/tcp barneybuffet/tor:latest
```

The image will:

* Tell Tor to create a hidden service in `/tor/hidden_services/<hostname>`
* Configure Tor to accept onion requests on a given port and redirect to an IP address and port

The onion address can be found in `/tor/hidden_services/<hostname>`

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


 


`'bitcoin:80:192.168.1.45:80 nextcloud:80:192.168.1.46:80 test:80:192.168.1.47:80'`
`'test=80:192.168.1.3:80,22:192.168.1.5:22 bitcoin=443:192.168.1.7:80,8443:192.168.1.5:443'`


#### References

* [Best Practices for Hosting Onion Services](https://riseup.net/en/security/network-security/tor/onionservices-best-practices)
* [Tor Hidden Services ](https://www.linuxjournal.com/content/tor-hidden-services)
