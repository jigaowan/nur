# Caddy on nix-darwin

This module ports the configuration interface of NixOS `services.caddy` to a
system LaunchDaemon. It supports Caddyfile generation, native JSON, custom
packages/adapters, automatic HTTPS, and plugins such as Cloudflare DNS and
`caddy-dynamicdns`. The default package contains only upstream Caddy modules.

Import `inputs.nur.darwinModules.caddy`, or use the existing
`inputs.nur.darwinModules.default` aggregate. Merely importing it has no service
or account side effects.

```nix
{
  imports = [ inputs.nur.darwinModules.caddy ];
  services.caddy = {
    enable = true;
    email = "admin@example.com";
    virtualHosts."app.example.com".extraConfig = ''
      reverse_proxy 127.0.0.1:8080
    '';
  };
}
```

## systemd comparison

The port was compared with the NixOS module at nixpkgs revision
`f3a73bcf5d1c5b75a66cf35a48957e30d41d647a`, its inherited Caddy 2.11.7
systemd unit, and nix-darwin 26.05 revision
`c3e90c89649b07d1a96e4b9dd6cd0d6e44b91a74`.

| NixOS / systemd behavior | Darwin implementation or limitation |
| --- | --- |
| `multi-user.target`, `ExecStart` | System LaunchDaemon, `RunAtLoad`, foreground `caddy run`; independent of login. Wrapper uses `exec`, retaining the main PID. |
| `User`, `Group` | `UserName`, `GroupName`; creates hidden `_caddy` with UID/GID 537 by default. Override `ids.uids._caddy` and `ids.gids._caddy` if necessary. Custom user and group must both be explicitly selected and already exist. |
| `StateDirectory`, `LogsDirectory` | Activation creates `dataDir` and `logDir` before launchd starts the daemon, with owner/group and mode 0750. Both default and custom paths are supported. Existing files are not recursively chowned. |
| Home and certificate persistence | Explicit `HOME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME` in both wrappers; independent of macOS GUI environment. Certificates are under `<dataDir>/.local/share/caddy`, autosave under `<dataDir>/.config/caddy`. |
| `reloadTriggers`, `ExecReload` | Stable `/etc/caddy/caddy_config` path and plist; activation calls `caddy reload --force` when the same plist is already running. Invalid reload fails activation while Caddy retains its active config. |
| `restartTriggers` | With `enableReload = false`, generated config changes alter the startup wrapper and plist, so nix-darwin unloads/loads the service. Package, adapter, environment-file path, identity and other plist changes also restart it. |
| `Restart=on-failure`, `RestartSec=5s` | `KeepAlive.SuccessfulExit = false`, `ThrottleInterval = 10`. No exact equivalent of `RestartPreventExitStatus=1` or the 10-attempt/4-hour start limit: failed startup is retried, too. |
| Graceful stop, `TimeoutStopSec` | launchd sends SIGTERM; Caddy drains connections. `ExitTimeOut = 30` bounds shutdown before SIGKILL (upstream systemd unit uses 5 seconds). |
| `EnvironmentFile` | Caddy's native `--envfile` parser on startup. For adapted configs, reload first runs `caddy adapt --envfile` into a private temporary JSON file, then reloads it. No shell sourcing or secret evaluation by Nix. |
| Journal and access logs | Default global log `<logDir>/caddy.log`, per-site access files, both rotated by Caddy. Bootstrap stdout/stderr go to `stdout.log`/`stderr.log`; launchd does not rotate these. |
| `Type=notify`, network ordering | No readiness notification or `network-online.target` equivalent. `launchctl load` succeeding does not prove HTTP is ready. Runtime failure retry covers transient startup errors; Caddy manages its own certificate renewal. |
| `LimitNOFILE=1048576` | Not copied: launchd's system-wide `NumberOfFiles` limits also change kernel limits. Tune `launchd.daemons.caddy.serviceConfig` explicitly if needed. |
| `CAP_NET_BIND_SERVICE`, `CAP_NET_ADMIN` | No Linux capabilities. Modern macOS permits unprivileged wildcard 80/443 listeners; a specific IPv4 bind address at a low port can still require privilege. Use higher ports/routing for such setups. No system-wide port policy is changed. |
| `ProtectSystem`, `ProtectHome`, `PrivateTmp`, `PrivateDevices`, `NoNewPrivileges`, `ReadWritePaths` | Not reproduced. Dedicated identity and restrictive permissions are useful but are not a systemd sandbox. |
| `security.acme`, `useACMEHost` | Not exported: nix-darwin has no equivalent ACME service/dependency module. Use Caddy's own ACME/DNS plugins, or externally managed cert/key files with `tls` in `extraConfig`. |
| `openFirewall`, Linux QUIC buffer sysctls | Not exported or silently translated. Configure macOS firewall/routing and buffer tuning separately. |

These differences do not prevent the reverse proxy, DNS-01 certificate renewal
and IPv6 interface-based DDNS configuration used by this deployment. Those
features run inside Caddy and its plugins, not inside systemd. This module does
not claim Linux-equivalent confinement or identical restart policy.

## Cloudflare DNS and IPv6 DDNS

Supply a Caddy package built with both `github.com/caddy-dns/cloudflare` and
`github.com/mholt/caddy-dynamicdns`, for example using `pkgs.caddy.withPlugins`
with pinned plugin versions and its verified source hash. Select that derivation
through `services.caddy.package`; the module does not select or upgrade plugins
implicitly.

```nix
{ caddyWithDNS, ... }:
{
  services.caddy = {
    enable = true;
    package = caddyWithDNS;
    environmentFile = "/run/agenix/caddy.env";
    globalConfig = ''
      acme_dns cloudflare {$CF_ACME_TOKEN}
      dynamic_dns {
        provider cloudflare {
          api_token {$CF_DDNS_TOKEN}
        }
        domains {
          example.com server
        }
        versions ipv6
        ip_source interface en0
      }
    '';
    virtualHosts."nas.example.com".extraConfig = ''
      reverse_proxy nas.internal:5000
    '';
  };
}
```

The example expects `caddyWithDNS` to be supplied as a module argument. The
runtime environment file contains `CF_ACME_TOKEN=...` and `CF_DDNS_TOKEN=...`.
Make it readable by `_caddy`, for example with agenix ownership `_caddy:_caddy`
and mode 0400. Provision secrets before Caddy activation; launchd has no agenix
dependency graph. Use quoted path strings, not Nix file literals or `readFile`,
for secrets. Generated Caddyfiles and plists contain paths and placeholders only.

`environmentFile` uses Caddy's dotenv grammar, not systemd's environment-file
grammar. Simple `KEY=VALUE` files work with both. Caddy's `reload` subcommand does
not accept `--envfile`, which is why the adapter step is needed. `{$VAR}` is
substituted before loading and can be updated on reload; runtime `{env.VAR}`
placeholders use the already-running process environment and require a restart
to pick up changed values, including in native JSON.

## Configuration and operation

- `virtualHosts` supports `hostName`, `serverAliases`, `listenAddresses`,
  `logFormat`, and `extraConfig`. Set a site's `logFormat = null` to disable its
  generated access logger.
- `settings` supplies native JSON and replaces generated Caddyfile content.
  An explicit `configFile` takes precedence over generated content; use
  `adapter = null` for a custom native JSON file.
- `enableReload` defaults to true and reloads on every activation with an
  unchanged, running plist. This also refreshes external certificates and
  substituted credentials. `caddy-reload` is installed for manual reloads;
  run it as the service identity, e.g. `sudo -u _caddy -g _caddy caddy-reload`.
- Keep the admin API enabled and its address stable when reloading. To disable
  it or change its listen address, use `enableReload = false` for that switch.
- `resume = true` requires `enableReload = false` so activation does not
  overwrite API-managed configuration. Startup then prefers the autosave file.
- External runtime file content changes are not Nix restart triggers. With
  reload disabled, restart explicitly after editing external files or rotating
  environment variables: `sudo launchctl kickstart -k system/org.nixos.caddy`.
- The service label follows `launchd.labelPrefix` (default `org.nixos`). A
  previously stopped/failed job with an unchanged plist is started on activation.
- Startup errors go to `<logDir>/stderr.log`. Avoid `--environ`, which would
  disclose environment secrets in logs. If you override Caddy logging to stderr,
  arrange rotation of the launchd log files yourself.

When migrating an existing installation, stop its old launchd job before binding
the same ports, and copy its certificate/account storage and autosave files to
the configured XDG locations with the new owner. The module does not stop other
jobs or copy storage from another user's home automatically. Changing the
service identity also requires transferring ownership of existing state.

## Verification

Tests accept already available nixpkgs and nix-darwin source directories; no
new flake input or lock update is required. Use matching release branches.

```sh
nix eval --impure --file darwin/caddy/tests/eval.nix \
  --arg nixpkgs /path/to/nixpkgs --arg darwin /path/to/nix-darwin passed
nix eval --impure --file darwin/caddy/tests/eval.nix \
  --arg nixpkgs /path/to/nixpkgs --arg darwin /path/to/nix-darwin \
  --argstr system x86_64-darwin passed
nix build --impure --no-link --print-out-paths \
  --file darwin/caddy/tests/eval.nix \
  --arg nixpkgs /path/to/nixpkgs --arg darwin /path/to/nix-darwin artifacts
python3 darwin/caddy/tests/runtime.py /nix/store/OUTPUT-caddy-darwin-test-artifacts
CADDY_TEST_LAUNCHD=1 python3 darwin/caddy/tests/runtime.py \
  /nix/store/OUTPUT-caddy-darwin-test-artifacts
```

The runtime tests use temporary directories and random loopback ports. The
optional launchd test briefly loads a uniquely named **user** job and unloads it
on exit; it does not install the real system daemon or create `_caddy`. Tests
cover actual generated wrappers, secret substitution without shell execution,
unchanged PID on reload, invalid-config rejection, graceful stop, crash restart,
and activation decisions. They do not exercise real ACME issuance, Cloudflare
updates, production traffic, or system-domain account creation.

## References

- [NixOS Caddy module](https://github.com/NixOS/nixpkgs/blob/f3a73bcf5d1c5b75a66cf35a48957e30d41d647a/nixos/modules/services/web-servers/caddy/default.nix)
- [Caddy upstream systemd unit](https://github.com/caddyserver/dist/blob/v2.11.7/init/caddy.service)
- [nix-darwin launchd activation](https://github.com/nix-darwin/nix-darwin/blob/c3e90c89649b07d1a96e4b9dd6cd0d6e44b91a74/modules/system/launchd.nix)
- [Apple launchd guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [Caddy CLI and signals](https://caddyserver.com/docs/command-line)
- [Apple XNU low-port binding checks](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/netinet/in_pcb.c)
