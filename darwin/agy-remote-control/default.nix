{ config, lib, ... }:
let
  cfg = config.services.agy-remote-control;
  args = import ../../modules/agy-remote-control/command.nix { inherit lib cfg; };
  configuredHome = config.users.users.${cfg.user}.home or null;
  home =
    cfg.environment.HOME
      or (if configuredHome == null then "/Users/${cfg.user}" else toString configuredHome);
in
{
  imports = [ ../../modules/agy-remote-control/options.nix ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.toLower cfg.user != "root";
        message = "services.agy-remote-control.user must name a non-root macOS account.";
      }
      {
        assertion = lib.hasPrefix "/" home;
        message = "The home directory for services.agy-remote-control must be an absolute path.";
      }
    ];

    launchd.daemons.agy-remote-control = {
      script = ''
        if [ "$(/usr/bin/id -u)" = 0 ]; then
          echo "Antigravity CLI Remote Control must run as a non-root user" >&2
          exit 1
        fi
        exec ${lib.escapeShellArgs args}
      '';
      environment = {
        HOME = home;
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      }
      // cfg.environment;
      serviceConfig = {
        UserName = cfg.user;
        WorkingDirectory = home;
        # agy reports missing daemon credentials here before its own log is initialized.
        StandardErrorPath = "/var/log/agy-remote-control.log";
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 10;
        Umask = 63;
        ProcessType = "Background";
      };
    };
  };
}
