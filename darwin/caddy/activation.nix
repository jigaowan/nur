{
  lib,
  cfg,
  label,
  plist,
  reloadCommand,
}:
let
  inherit (lib) escapeShellArg;
  installedPlist = "/Library/LaunchDaemons/${label}.plist";
  target = "system/${label}";
in
''
  /usr/bin/install -d -m 0750 -o ${escapeShellArg cfg.user} -g ${escapeShellArg cfg.group} \
    ${escapeShellArg cfg.dataDir} ${escapeShellArg cfg.logDir}

  # A changed plist is restarted by nix-darwin itself. An unchanged plist needs
  # an explicit reload, or a start if it was previously stopped or failed.
  if /usr/bin/cmp -s ${escapeShellArg (toString plist)} ${escapeShellArg installedPlist}; then
    caddy_launchd_state=$(/bin/launchctl print ${escapeShellArg target} 2>/dev/null || true)
    if printf '%s\n' "$caddy_launchd_state" | /usr/bin/grep -E '^[[:space:]]*pid = [0-9]+$' >/dev/null; then
      ${
        if cfg.enableReload then
          ''
            echo "reloading Caddy configuration..." >&2
            ${reloadCommand}
          ''
        else
          ":"
      }
    elif [ -n "$caddy_launchd_state" ]; then
      /bin/launchctl kickstart ${escapeShellArg target}
    else
      /bin/launchctl load -w ${escapeShellArg installedPlist}
    fi
  fi
''
