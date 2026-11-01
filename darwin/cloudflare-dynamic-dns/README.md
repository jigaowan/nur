# Cloudflare dynamic DNS on nix-darwin

Import `darwinModules.cloudflare-dynamic-dns` or `darwinModules.default`.
The module runs nixpkgs' `cloudflare-dynamic-dns` as a root LaunchDaemon at
boot and every five minutes by default. It updates Cloudflare AAAA records.

```nix
services.cloudflare-dynamic-dns = {
  enable = true;
  interface = "en0";
  domains = [ "host.example.com" ];
  tokenFile = config.sops.secrets.cloudflare-ddns.path;
  interval = 300;
};
```

Before every run, `ifconfig -L` supplies the first global IPv6 address on the
chosen interface that is not temporary, deprecated, tentative or duplicated.
If none is available, the run fails without changing DNS and launchd retries at
the next interval. The client handles Cloudflare API operations.

The token file must be root-readable and contain a Cloudflare API token with
Zone DNS Edit and Zone Read permissions. The token is read at runtime into the
client's environment, never embedded in the Nix store. Existing records' proxy
status is preserved. In single-host mode the client may remove additional AAAA
records for the same name. Output goes to `/var/log/cloudflare-dynamic-dns.log`.
Verify the selected address and DNS record on the target Mac after deployment.
