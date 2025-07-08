#### X.509 CA certificates for my infrastructure (currently unused)

All files are named according to the cert's reverse-DNS FQDN, mostly to make `ls -l` readable. Commands used to generate the certs:

- root CA for domain
```sh
openssl req -new -x509 -newkey ed25519 -days 3600 \
    -out /etc/nixos/core/certs/net.azey.crt -keyout /etc/nixos/sops/certs/net.azey.key \
    -addext "nameConstraints=critical, permitted;DNS:azey.net"
```

- CA for k8s cluster
```sh
openssl req -new -x509 -newkey ed25519 -days 3600 \
    -out /etc/nixos/core/certs/net.azey.k8s.primary.crt -keyout /etc/nixos/sops/certs/net.azey.k8s.primary.key \
    -CA /etc/nixos/core/certs/net.azey.crt -CAkey /etc/nixos/sops/certs/net.azey.key \
    -addext "basicConstraints=critical, CA:TRUE, pathlen:1" \
    -addext "nameConstraints=critical, permitted;DNS:primary.k8s.azey.net"
```

- CA for k8s VM host
```sh
openssl req -new -x509 -newkey ed25519 -days 3600 \
    -out /etc/nixos/core/certs/net.azey.k8s.primary.astra.crt -keyout /etc/nixos/sops/certs/net.azey.k8s.primary.astra.key \
    -CA /etc/nixos/core/certs/net.azey.k8s.primary.crt -CAkey /etc/nixos/sops/certs/net.azey.k8s.primary.key \
    -addext "basicConstraints=critical, CA:TRUE, pathlen:0" \
    -addext "nameConstraints=critical, permitted;DNS:astra.primary.k8s.azey.net, permitted;DNS:api.primary.k8s.azey.net"
```
