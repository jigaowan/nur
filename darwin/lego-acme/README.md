# lego DNS-01 on nix-darwin

The Darwin module manages Cloudflare DNS-01 certificates with nixpkgs lego.
It runs as root, reads the token from a runtime file, keeps lego account state
private, and checks daily for renewal.

```nix
services.lego-acme.certs.home = {
  domain = "*.example.com";
  email = "admin@example.com";
  tokenFile = config.sops.secrets.cloudflare-token.path;
  server = "https://acme-v02.api.letsencrypt.org/directory";
  group = "_caddy";
  reloadServices = [ "org.nixos.caddy" ];
};

services.caddy.virtualHosts."nas.example.com".extraConfig = ''
  tls ${config.services.lego-acme.certs.home.directory}/fullchain.pem ${config.services.lego-acme.certs.home.directory}/key.pem
  reverse_proxy 192.168.1.2:5000
'';
```

`directory` is `/var/lib/acme/<name>`, analogous to NixOS ACME. The module
copies the certificate and private key there with mode 0640 and the configured
group; only members of that group should have access to the private key.
Account files remain root-only. It restarts the listed system launchd services
after the certificate changes, and retries a failed restart on a later run.
On first deployment a dependent service can fail until issuance completes.
Errors are logged to `/var/log/lego-acme-<name>.log`.

The service starts after sops-nix's `postActivation` on system activation and
otherwise runs on its launchd interval. A staging server can be used for a
test issuance, but its certificates are not publicly trusted.
