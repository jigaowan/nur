{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.snell-server;
  listenAddress =
    if lib.hasInfix ":" cfg.address && !(lib.hasPrefix "[" cfg.address) then
      "[${cfg.address}]"
    else
      cfg.address;
  listenPorts = map (endpoint: lib.toInt (lib.last (lib.splitString ":" endpoint))) cfg.listen;
  configFile = pkgs.writeText "config.conf" ''
    [snell-server]
    listen=${lib.concatStringsSep "," cfg.listen}
    psk=${cfg.psk}
    mode=${cfg.mode}
    dns-ip-preference=${cfg.dnsIPPreference}
    ${lib.optionalString (cfg.dns != [ ]) "dns=${lib.concatStringsSep "," cfg.dns}"}
  '';
in
{
  imports = [
    (lib.mkRemovedOptionModule [
      "services"
      "snell-server"
      "obfs"
    ] "Snell 6 no longer supports HTTP obfuscation. Use services.snell-server.mode instead.")
  ];
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
      listen = lib.mkOption {
        type = lib.types.nonEmptyListOf (lib.types.strMatching "([[][^]]+[]]|[^:,[:space:]]+):[0-9]+");
        default = [ "${listenAddress}:${toString cfg.port}" ];
        example = [
          "0.0.0.0:7800"
          "[::]:7800"
        ];
        description = "Listening endpoints. Overrides address and port when set explicitly.";
      };
      psk = lib.mkOption {
        type = lib.types.str;
        description = "Pre-shared key, between 12 and 255 bytes. This value is stored in the Nix store.";
      };
      ipv6 = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Compatibility option: false defaults dnsIPPreference to ipv4-only.";
      };
      mode = lib.mkOption {
        type = lib.types.enum [
          "default"
          "unshaped"
          "unsafe-raw"
        ];
        default = "default";
        description = "Transport mode; must match the client. unsafe-raw disables encryption.";
      };
      dnsIPPreference = lib.mkOption {
        type = lib.types.enum [
          "default"
          "prefer-ipv4"
          "prefer-ipv6"
          "ipv4-only"
          "ipv6-only"
        ];
        default = if cfg.ipv6 then "default" else "ipv4-only";
        description = "Address-family preference for DNS results.";
      };
      dns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Custom DNS server addresses; an empty list uses the system resolver.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.stringLength cfg.psk >= 12 && builtins.stringLength cfg.psk <= 255;
        message = "services.snell-server.psk must contain between 12 and 255 bytes.";
      }
      {
        assertion = lib.all (port: port >= 1 && port <= 65535) listenPorts;
        message = "services.snell-server.listen ports must be between 1 and 65535.";
      }
    ];
    networking.firewall.allowedTCPPorts = lib.unique listenPorts;
    systemd.services.snell-server = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "systemd-resolved.service"
      ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/snell-server -c ${configFile}";
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
