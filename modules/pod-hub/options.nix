{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.pod-hub;
  toml = pkgs.formats.toml { };
in
{
  options.services.pod-hub = {
    enable = lib.mkEnableOption "Pod Hub YouTube-to-podcast service";

    package = lib.mkPackageOption pkgs "pod-hub" { };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "HTTP listen address.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "HTTP listen port.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8000";
      description = "Public URL used in generated feeds.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pod-hub";
      description = "Absolute path for the private database, backups and working state.";
    };

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pod-hub/output";
      description = "Absolute path for published podcast folders.";
    };

    ytdlpPackage = lib.mkPackageOption pkgs "yt-dlp" { };

    ytdlpPython = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional absolute path to a Python interpreter that can import yt_dlp (use when supplying yt-dlp from another nixpkgs with a different Python version).";
    };

    ffmpegPackage = lib.mkPackageOption pkgs "ffmpeg" { };

    jsRuntimePackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.deno;
      description = "yt-dlp JavaScript runtime package.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to an optional runtime KEY=VALUE environment file for secrets.";
    };

    settings = lib.mkOption {
      type = toml.type;
      default = { };
      description = "Additional TOML settings. Use stateDir/outputDir instead of settings.paths, and keep secrets in environmentFile.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      (lib.mapAttrsToList (name: value: {
        assertion = value == null || lib.hasPrefix "/" value;
        message = "services.pod-hub.${name} must be an absolute path.";
      }) {
        inherit (cfg) stateDir outputDir environmentFile ytdlpPython;
      })
      ++ [
        {
          assertion = !(cfg.settings ? paths);
          message = "services.pod-hub.settings.paths must not be set; configure services.pod-hub.stateDir and services.pod-hub.outputDir instead.";
        }
      ];
  };
}
