# Antigravity CLI Remote Control

Import `nixosModules.agy-remote-control` or `darwinModules.agy-remote-control`
from the NUR flake. Both platform defaults include the module.

```nix
services.agy-remote-control = {
  enable = true;
  instanceName = "dev-workstation";
  # Optional when pkgs.antigravity-cli is available and allowed by Nixpkgs.
  package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-cli;

  # Existing non-root account on either platform.
  user = "alice";
};
```

The system service starts at boot as `user` on both platforms. It uses the
account's home directory for credentials and as the working directory. On macOS
the home defaults to `/Users/<name>` if `users.users.<name>.home` is unset. Set
`environment.HOME` to override the home and working directory.
`environment` accepts non-secret settings such as proxy variables.
The service connects to Google's Remote Control dashboard without opening a
firewall port. The module uses the foreground process registered by
`agy remote-control start`, verified with `agy` 1.5.13.

Before the first successful start, sign in as the service account with `agy`
or `agy acp --login`. Initialize the daemon credentials with the same CLI
package and home directory that the service uses.

```sh
agy remote-control start --session
agy remote-control stop
```

`start` prepares the credentials in the user's home, and `stop` unregisters
the temporary upstream job. Start or restart the Nix-managed service once
the credentials are ready. If you need to initialize them again, stop the
Nix-managed service first and then repeat the commands above.

If migrating from the older NixOS user service, stop it as the service user
with `systemctl --user stop agy-remote-control.service` before switching.
Remove any `services.agy-remote-control.linger` setting from the configuration.

If migrating from the older nix-darwin LaunchAgent, unload it in its original
login session (`launchctl bootout "gui/$(id -u)/org.nixos.agy-remote-control"`)
and remove its plist from `~/Library/LaunchAgents` if it is still present.
On either platform, existing daemon credentials can be reused when the service
account and home directory are the same.

- On NixOS, check `systemctl status agy-remote-control.service` and
  `journalctl -u agy-remote-control.service`. Restart with
  `sudo systemctl restart agy-remote-control.service`.
- On nix-darwin, check `sudo launchctl print system/org.nixos.agy-remote-control`.
  Restart with `sudo launchctl kickstart -k system/org.nixos.agy-remote-control`.
  Both commands assume the default `launchd.labelPrefix`.

Find the machine in the [Antigravity Remote Control dashboard](https://antigravity.google.com/).
