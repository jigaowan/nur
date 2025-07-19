{ config, lib, pkgs, ... }:
let
  cfg = config.services.anytls-go;
in {
  options = {
    services.anytls-go = {
      enable = lib.mkEnableOption "anytls-go";
      package = lib.mkPackageOption pkgs "anytls-go" { };
      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 443;
      };
      password = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];
    systemd.services.anytls-go = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "systemd-resolved.service" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/server -l ${cfg.host}:${builtins.toString(cfg.port)} -p ${cfg.password}";
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
