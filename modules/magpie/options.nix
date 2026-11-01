{ config, lib, pkgs, ... }:
let
  cfg = config.services.magpie;
in
{
  options.services.magpie = {
    enable = lib.mkEnableOption "the Magpie gateway";
    package = lib.mkPackageOption pkgs "magpie-cli" { };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3425";
      example = "127.0.0.1:3426";
      description = "Gateway listen address as host:port.";
    };
    web = {
      enable = lib.mkEnableOption "the Magpie web console";
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:3430";
        example = "127.0.0.1:3431";
        description = "Web console listen address as host:port.";
      };
      keyFile = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "/.+");
        default = null;
        example = lib.literalExpression ''config.sops.secrets."MAGPIE_WEB_KEY".path'';
        description = ''
          Absolute runtime path to a file containing the web access key, for
          example a sops-nix or agenix secret. Null lets Magpie generate a key
          at each start. The key is read at service start, not during evaluation.
        '';
      };
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { MAGPIE_NO_STATS = "1"; };
      description = ''
        Non-secret environment variables passed to Magpie. These are stored in
        the Nix store. Set PATH here if plugins or agents need additional tools.
        HOME and XDG variables determine which configuration and credentials
        Magpie uses; see the platform-specific service documentation.
      '';
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--web" ];
      description = ''
        Additional arguments to magpie serve. Arguments are public in the Nix
        store and process list; do not place credentials here.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.environment ? MAGPIE_ADDR);
        message = "Use services.magpie.listenAddress instead of environment.MAGPIE_ADDR.";
      }
      {
        assertion = cfg.web.keyFile == null || cfg.web.enable;
        message = "services.magpie.web.keyFile requires web.enable.";
      }
      {
        assertion = cfg.web.keyFile == null || !(cfg.environment ? MAGPIE_WEB_KEY);
        message = "Set only one of services.magpie.web.keyFile and environment.MAGPIE_WEB_KEY.";
      }
    ];
  };
}
