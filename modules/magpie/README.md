# Magpie gateway

The NUR default NixOS and nix-darwin modules include `services.magpie`.
Both run `magpie serve` from the NUR `magpie-cli` package and restart it after
failure. NixOS runs one system service at boot under a dedicated `magpie`
account; Darwin runs a user agent after login. The package is referenced by
the service but is not installed into the system profile, so it can coexist
with the GUI package. Install `pkgs.magpie-cli` separately if its command is
needed on PATH and no other package already provides `magpie`.
The current NUR package is marked `unfree`; allow `magpie-cli` through your
existing `nixpkgs.config.allowUnfreePredicate` or `allowUnfree` configuration.

```nix
services.magpie = {
  enable = true;
  listenAddress = "127.0.0.1:3425";
  web = {
    enable = true;
    listenAddress = "127.0.0.1:3430";
    keyFile = config.sops.secrets."MAGPIE_WEB_KEY".path;
    # Or: keyFile = config.age.secrets.magpie-web-key.path;
  };
  # Optional: include the agent CLIs and runtimes used by plugins.
  environment.PATH = lib.makeBinPath [ pkgs.bun pkgs.nodejs ];
};
```

On NixOS, systemd creates `/var/lib/magpie` as the private, persistent home
for the `magpie` service account. On Darwin,
nix-darwin installs the user agent for `system.primaryUser`.

The gateway's `listenAddress` defaults to `127.0.0.1:3425`, matching the
upstream default; the module passes it as `MAGPIE_ADDR`. Magpie reads and writes the service
account's configuration, cache, credentials and agent settings. On NixOS those
are separate from a desktop user's existing Magpie configuration: configure
providers and logins in the service account, or use the service's web console.
For example, run the CLI as the service user with HOME set to `/var/lib/magpie`.
On Darwin the agent uses the primary user's existing configuration.
Set any required XDG paths, agent paths, proxy variables and PATH explicitly in
`environment`: a service does not inherit an interactive shell's environment.
Environment values and `extraArgs` are world-readable in the Nix store; do not
put API keys, proxy passwords or web keys there. Use Magpie's own credential
storage, or an externally managed service environment for secrets.

`web.enable` starts the optional web console; consult the
[upstream service documentation](https://github.com/yetone/magpie/blob/v0.1.2500/docs/reference.md#as-a-background-service)
for its authentication and listening behavior. `web.keyFile` refers to a
runtime file containing the key only, not a `KEY=value` environment file. It
may be the path of a sops-nix or agenix secret; its contents are read at
service start and are not copied into the Nix store. Without a key file,
Magpie generates a new key at each start. Linux systemd loads the file as a
credential, so it can read a root-owned secret. On Darwin the primary user
running the agent must be able to read the secret. Provision the secret before
the service starts and restart the service after changing its contents; secret
rotation alone does not restart it. Magpie prints the web access link including
the key to its service output, so protect access to logs. Review access
controls before listening beyond loopback. The module does not open firewall
ports or configure TLS.

Stop and remove any `magpie daemon install` user service and disable Magpie
autostart before enabling this service, to avoid competing gateway processes.
Check Linux logs with `journalctl -u magpie`. Darwin launchd manages the
agent through nix-darwin; this module does not create a persistent log file.
Use Nix to update the package, rather than Magpie's self-updater, because the
Nix store is immutable.
