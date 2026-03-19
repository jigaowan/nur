{ config, lib, pkgs, ... }:
let
  cfg = config.services.mcp-nixos;
in {
  options = {
    services.mcp-nixos = {
      enable = lib.mkEnableOption "mcp-nixos";
      package = lib.mkPackageOption pkgs "mcp-nixos" { };
      transport = lib.mkOption {
        type = lib.types.str;
        default = "http";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8000;
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "/mcp";
      };
      stateless = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.mcp-nixos = {
      serviceConfig = {
        EnvironmentVariables = {
          MCP_NIXOS_TRANSPORT = cfg.transport;
        } // lib.optionalAttrs (cfg.transport == "http") {
          MCP_NIXOS_HOST = cfg.host;
          MCP_NIXOS_PORT = builtins.toString cfg.port;
          MCP_NIXOS_PATH = cfg.path;
        } // lib.optionalAttrs (cfg.transport == "http" && cfg.stateless) {
          MCP_NIXOS_STATELESS_HTTP = "1";
        };
        ProgramArguments = [ "${cfg.package}/bin/mcp-nixos" ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
      };
      managedBy = "services.mcp-nixos.enable";
    };
  };
}
