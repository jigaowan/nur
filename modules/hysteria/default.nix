{ config, lib, pkgs, ... }:
let
  cfg = config.services.hysteria;
  configFile = pkgs.writeText "config.yaml" ''
  tls:
    cert: ${cfg.cert}
    key: ${cfg.key}
  auth:
    type: password
    password: ${cfg.password}
  masquerade:
    type: proxy
    proxy:
      url: https://news.ycombinator.com/
      rewriteHost: true
  '';
in {
  options = {
    services.hysteria = {
      enable = lib.mkEnableOption "hysteria";
      package = lib.mkPackageOption pkgs "hysteria" { };
      password = lib.mkOption {
        type = lib.types.str;
        default = "change-it";
      };
      cert = lib.mkOption {
        type = lib.types.path;
        default = "";
      };
      key = lib.mkOption {
        type = lib.types.path;
        default = "";
      };
      enableRange = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      portFrom = lib.mkOption {
        type = lib.types.port;
        default = 30000;
      };
      portTo = lib.mkOption {
        type = lib.types.port;
        default = 40000;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [ 443 ];
    networking.firewall.allowedUDPPortRanges = lib.mkIf cfg.enableRange [ { from = cfg.portFrom; to = cfg.portTo; } ];
    networking.firewall.extraCommands = lib.mkIf cfg.enableRange ''
      iptables -t nat -A PREROUTING -i eth0 -p udp --dport ${toString cfg.portFrom}:${toString cfg.portTo} -j REDIRECT --to-ports 443
      ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport ${toString cfg.portFrom}:${toString cfg.portTo} -j REDIRECT --to-ports 443
    '';
    networking.firewall.extraStopCommands = lib.mkIf cfg.enableRange ''
      iptables -t nat -D PREROUTING -i eth0 -p udp --dport ${toString cfg.portFrom}:${toString cfg.portTo} -j REDIRECT --to-ports 443 || true
      ip6tables -t nat -D PREROUTING -i eth0 -p udp --dport ${toString cfg.portFrom}:${toString cfg.portTo} -j REDIRECT --to-ports 443 || true
    '';
    systemd.services.hysteria = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "systemd-resolved.service" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/hysteria server --disable-update-check -c ${configFile}";
        Restart = "always";
      };
    };
  };
}
