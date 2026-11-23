{
  config,
  lib,
  utils,
  ...
}:
let
  cfg = config.services.agy-remote-control;
  args = import ./command.nix { inherit lib cfg; };
  user = config.users.users.${cfg.user} or { };
  # Both Environment and WorkingDirectory expand systemd specifiers.
  home = lib.replaceStrings [ "%" ] [ "%%" ] (
    toString (cfg.environment.HOME or (user.home or "/var/empty"))
  );
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (user.isNormalUser or false || user.isSystemUser or false) && user.uid != 0;
        message = "services.agy-remote-control.user must name an existing non-root NixOS user.";
      }
      {
        assertion = lib.hasPrefix "/" home;
        message = "The home directory for services.agy-remote-control must be an absolute path.";
      }
    ];

    systemd.services.agy-remote-control = {
      description = "Antigravity CLI Remote Control";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ config.system.path ];
      environment =
        cfg.environment
        // {
          HOME = home;
        }
        // lib.optionalAttrs (cfg.environment ? PATH) {
          PATH = lib.mkForce cfg.environment.PATH;
        };
      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = home;
        ExecStart = utils.escapeSystemdExecArgs args;
        Restart = "on-failure";
        RestartSec = 10;
        UMask = "0077";
      };
    };
  };
}
