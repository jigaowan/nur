{ config, lib, pkgs, ... }:
let
  cfg = config.services.snell-server;
  configFile = pkgs.writeText "config.conf" ''
    [snell-server]
    listen=${cfg.address}:${builtins.toString(cfg.port)}
    psk=${cfg.psk}
    ipv6=${if cfg.ipv6 then "true" else "false"}
  '';
in {
  options = {
    services.snell-server = {
      enable = lib.mkEnableOption "snell-server";
      package = lib.mkPackageOption pkgs "snell-server" { };
      address = lib.mkOption {
        type = lib.types.str;
        default = "::0";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 7800;
      };
      psk = lib.mkOption {
        type = lib.types.str;
        default = "change-it";
      };
      ipv6 = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [cfg.port];
    systemd.services.snell-server = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "systemd-resolved.service" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/snell-server -c ${configFile}";
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
