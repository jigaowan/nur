{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.scanocr-client;

  configFile = pkgs.writeText "scanocr-client.toml" ''
    server_url = ${builtins.toJSON cfg.serverUrl}
    token = ${builtins.toJSON cfg.token}
    client_name = ${builtins.toJSON cfg.clientName}
    notify = ${lib.boolToString cfg.notify}
  '';

  configuredPackage = pkgs.writeShellScriptBin "scanocr-client" ''
    if [ "''${1-}" = "--version" ] || [ "''${1-}" = "--config" ]; then
      exec ${lib.getExe cfg.package} "$@"
    fi

    exec ${lib.getExe cfg.package} --config ${configFile} "$@"
  '';
in
{
  options.programs.scanocr-client = {
    enable = lib.mkEnableOption "ScanOCR Linux screenshot client";

    package = lib.mkPackageOption pkgs "scanocr-client" { };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8732";
      description = "Absolute HTTP or HTTPS URL of the ScanOCR server.";
    };

    token = lib.mkOption {
      type = lib.types.str;
      example = "replace-with-client-token";
      description = ''
        Bearer token used to authenticate with the ScanOCR server. The token
        is written to the generated configuration and therefore stored in the
        Nix store.
      '';
    };

    clientName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Client name included in uploaded capture metadata.";
    };

    notify = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to display desktop notifications.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ configuredPackage ];
  };
}
