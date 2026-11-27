{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.pod-hub;
  defaultAccount = "pod-hub";
  configFile = import ./config.nix { inherit lib pkgs cfg; };
in
{
  imports = [ ./options.nix ];

  options.services.pod-hub = {
    user = lib.mkOption {
      type = lib.types.str;
      default = defaultAccount;
      description = "Service user.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = defaultAccount;
      description = "Service group.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups = lib.optionalAttrs (cfg.group == defaultAccount) {
      ${defaultAccount} = { };
    };
    users.users = lib.optionalAttrs (cfg.user == defaultAccount) {
      ${defaultAccount} = {
        isSystemUser = true;
        group = cfg.group;
      };
    };

    systemd.tmpfiles.settings."10-pod-hub" = {
      ${cfg.stateDir}.d = {
        mode = "0750";
        user = cfg.user;
        group = cfg.group;
      };
      ${cfg.outputDir}.d = {
        mode = "0755";
        user = cfg.user;
        group = cfg.group;
      };
    };

    systemd.services.pod-hub = {
      description = "Pod Hub podcast service";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      environment.PODHUB_CONFIG = configFile;
      serviceConfig =
        {
          ExecStart = "${lib.getExe cfg.package} serve";
          User = cfg.user;
          Group = cfg.group;
          Restart = "on-failure";
          RestartSec = 5;
          TimeoutStopSec = 30;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [
            cfg.stateDir
            cfg.outputDir
          ];
        }
        // lib.optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        };
    };
  };
}
