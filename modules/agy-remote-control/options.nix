{ lib, pkgs, ... }:
{
  options.services.agy-remote-control = {
    enable = lib.mkEnableOption "the Antigravity CLI Remote Control daemon";

    package = lib.mkPackageOption pkgs "antigravity-cli" {
      default = if pkgs ? antigravity-cli then "antigravity-cli" else null;
      extraDescription = "The package must provide {command}`agy`.";
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
}
