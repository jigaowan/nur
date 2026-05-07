{ config, lib, pkgs, ... }:
let
  cfg = config.services.trojan-go;

  sslModule = lib.types.submodule {
    options = {
      cert = lib.mkOption {
        type = lib.types.path;
        default = "";
      };
      key = lib.mkOption {
        type = lib.types.path;
        default = "";
      };
      sni = lib.mkOption {
        type = lib.types.str;
        default = "host";
      };
    };
  };

  wsModule = lib.types.submodule {
    options = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "/websocket";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "host";
      };
    };
  };

  filteredCfg = builtins.removeAttrs cfg [ "enable" "package" ];
  configFile = pkgs.writeText "config.json" (builtins.toJSON filteredCfg);
in {
  options = {
    services.trojan-go = {
      enable = lib.mkEnableOption "trojan-go";
      package = lib.mkPackageOption pkgs "trojan-go" { };
      run_type = lib.mkOption {
        type = lib.types.enum [ "server" "client" ];
        default = "server";
      };
      local_addr = lib.mkOption {
        type = lib.types.str;
        default = "::";
      };
      local_port = lib.mkOption {
        type = lib.types.number;
        default = 443;
      };
      remote_addr = lib.mkOption {
        type = lib.types.str;
        default = "209.216.230.207";
      };
      remote_port = lib.mkOption {
        type = lib.types.number;
        default = 443;
      };
      password = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      ssl = lib.mkOption {
        type = sslModule;
        default = { };
      };
      websocket = lib.mkOption {
        type = wsModule;
        default = { };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [cfg.local_port];
    boot.kernel.sysctl = {
      "net.core.rmem_max"=16777216;
      "net.core.wmem_max"=16777216;
    };
    systemd.services.trojan-go = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "systemd-resolved.service" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/trojan-go -config ${configFile}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    systemd.services."restart-trojan-go" = {
      script = "systemctl restart trojan-go.service";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      startAt = "hourly";
    };
  };
}
