{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.agy-remote-control;
in
{
  options.services.agy-remote-control = {
    enable = lib.mkEnableOption "the Antigravity CLI Remote Control daemon";

    package = lib.mkPackageOption pkgs "antigravity-cli" {
      extraDescription = "The package must provide {command}`agy`.";
    };

    user = lib.mkOption {
      type = lib.types.nonEmptyStr;
      example = "alice";
      description = "Existing non-root account used to run the service and initialize its daemon credentials.";
    };

    instanceName = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = null;
      example = "dev-workstation";
      description = ''
        Instance name displayed in Antigravity Remote Control.
        When null, agy chooses the name using its user configuration.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Non-secret environment variables for the daemon and its child processes.
        These values are stored in the Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
