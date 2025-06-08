{ config, lib, pkgs, ... }:
let
  cfg = config.services.sing-box;
  jsonFormat = pkgs.formats.json { };
  configFile = pkgs.writeText "config.json" (builtins.toJSON cfg.settings);
in {
  options = {
    services.sing-box = {
      enable = lib.mkEnableOption "sing-box";
      package = lib.mkPackageOption pkgs "sing-box" { };
      tcp_port = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
      };
      udp_port = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
      };
      settings = lib.mkOption {
        type = lib.types.submodule { freeformType = jsonFormat.type; };
        default = { };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = cfg.tcp_port;
    networking.firewall.allowedUDPPorts = cfg.udp_port;
    systemd.services.sing-box = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "systemd-resolved.service" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/sing-box -c ${configFile} run";
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
