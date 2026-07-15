{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.scanocr-server;

  absoluteOrHomePath = lib.types.str // {
    check = value: lib.types.str.check value && (lib.hasPrefix "/" value || lib.hasPrefix "~/" value);
    description = "string starting with / or ~/";
  };

  settingsFormat = pkgs.formats.toml { };
  configFile = settingsFormat.generate "scanocr-server.toml" (
    {
      server = {
        inherit (cfg) host port;
        open_browser = cfg.openBrowser;
        max_upload_bytes = cfg.maxUploadBytes;
        managed = true;
      };
      auth =
        lib.optionalAttrs (cfg.token != null) {
          token = cfg.token;
        }
        // lib.optionalAttrs (cfg.tokenFile != null) {
          token_file = cfg.tokenFile;
        };
      defaults = {
        ocr_engine = cfg.ocrEngine;
        translation_engine = cfg.translationEngine;
        source_language = cfg.sourceLanguage;
        target_language = cfg.targetLanguage;
      };
    }
    // lib.optionalAttrs (cfg.dataDir != null) {
      paths.data_dir = cfg.dataDir;
    }
  );
in
{
  options.services.scanocr-server = {
    enable = lib.mkEnableOption "ScanOCR screenshot OCR and translation server";

    package = lib.mkPackageOption pkgs "scanocr-server" { };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which ScanOCR Server listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8732;
      description = "Port on which ScanOCR Server listens.";
    };

    openBrowser = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the ScanOCR web interface when the server starts.";
    };

    maxUploadBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 536870912;
      description = "Maximum size in bytes of an uploaded capture.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr absoluteOrHomePath;
      default = null;
      example = "~/Library/Application Support/ScanOCR/token";
      description = ''
        File containing the bearer token used to authenticate API requests.
        ScanOCR Server requires this file to have mode 0600 at runtime. The
        token is referenced by path and is not copied into the Nix store.
      '';
    };

    token = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "replace-with-a-random-token";
      description = ''
        Bearer token written directly to the generated ScanOCR Server
        configuration. Use either this option or tokenFile, but not both.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.nullOr absoluteOrHomePath;
      default = null;
      example = "~/Library/Application Support/ScanOCR";
      description = ''
        Directory in which ScanOCR Server stores its database, captures, and
        thumbnails. The upstream per-user default is used when this is null.
      '';
    };

    ocrEngine = lib.mkOption {
      type = lib.types.str;
      default = "vision";
      description = "Default OCR engine.";
    };

    translationEngine = lib.mkOption {
      type = lib.types.str;
      default = "apple-translation";
      description = "Default translation engine.";
    };

    sourceLanguage = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "Default source language as a BCP 47 language tag, or auto.";
    };

    targetLanguage = lib.mkOption {
      type = lib.types.str;
      default = "zh-Hans";
      description = "Default target language as a BCP 47 language tag.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.token != null) != (cfg.tokenFile != null);
        message = "Set exactly one of services.scanocr-server.token or services.scanocr-server.tokenFile.";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.scanocr-server = {
      serviceConfig = {
        ProgramArguments = [
          (lib.getExe cfg.package)
          "--config"
          "${configFile}"
          "serve"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
      };
      managedBy = "services.scanocr-server.enable";
    };
  };
}
