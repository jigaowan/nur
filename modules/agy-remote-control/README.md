# Antigravity CLI Remote Control

Import `nixosModules.agy-remote-control` or `darwinModules.agy-remote-control`
from the NUR flake. Both platform defaults include the module.

```nix
services.agy-remote-control = {
  enable = true;
  instanceName = "dev-workstation";

  # Existing non-root account on either platform.
  user = "alice";
};
```

The module defaults to `pkgs.antigravity-cli`. The default NUR modules provide
this package for Intel and Apple Silicon Macs and for x86_64 and aarch64 Linux.
When importing the standalone module, add the NUR `overlays.default` to get
the same package. Set `package` to use a different build of `agy`. Nixpkgs
must allow the unfree `antigravity-cli` license.
Enabling the service also makes its `agy` available in the system profile at
`/run/current-system/sw/bin/agy` on both platforms.

The system service starts at boot as `user` on both platforms. It uses the
account's home directory for credentials and as the working directory. On macOS
the home defaults to `/Users/<name>` if `users.users.<name>.home` is unset. Set
`environment.HOME` to override the home and working directory.
`environment` accepts non-secret settings such as proxy variables.
The service runs the foreground process normally registered by
`agy remote-control start`.

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

Existing daemon credentials can be reused when the service account and home
directory are the same.

- On NixOS, check `systemctl status agy-remote-control.service` and
  `journalctl -u agy-remote-control.service`. Restart with
  `sudo systemctl restart agy-remote-control.service`.
- On nix-darwin, check `sudo launchctl print system/org.nixos.agy-remote-control`.
  Restart with `sudo launchctl kickstart -k system/org.nixos.agy-remote-control`.
  Both commands assume the default `launchd.labelPrefix`.

Find the machine in the [Antigravity Remote Control dashboard](https://antigravity.google.com/).
