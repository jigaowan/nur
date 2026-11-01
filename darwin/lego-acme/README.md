# lego DNS-01 on nix-darwin

This module currently supports isolated Cloudflare DNS-01 staging checks. It
uses nixpkgs lego, runs as root, reads a token file at runtime, and stores its
account and certificate material in a root-only state directory. It runs after
sops-nix's `postActivation` hook and checks again daily via launchd.

```nix
services.lego-acme.certs.staging = {
  domain = "*.example.com";
  email = "admin@example.com";
  tokenFile = config.sops.secrets.cloudflare-token.path;
  server = "https://acme-staging-v02.api.letsencrypt.org/directory";
};
```

The job creates real temporary DNS TXT challenge records. Its staging
certificate is not publicly trusted. This module does not yet install
certificates for Caddy or reload services; do not switch production TLS to it.
Check `/var/log/lego-acme-staging.log` for the result.
