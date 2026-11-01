{ config, lib, pkgs, ... }:
let
  cfg = config.services.magpie;
  args = [ (lib.getExe cfg.package) "serve" ]
    ++ lib.optional cfg.web.enable "--web=${cfg.web.listenAddress}"
    ++ cfg.extraArgs;
  start = pkgs.writeShellScript "magpie-start" ''
    ${lib.optionalString (cfg.web.keyFile != null) ''
      MAGPIE_WEB_KEY=$(< ${lib.escapeShellArg cfg.web.keyFile})
      if [ -z "$MAGPIE_WEB_KEY" ]; then
        echo "Magpie web key is empty or unreadable" >&2
        exit 1
      fi
      export MAGPIE_WEB_KEY
    ''}
    exec ${lib.escapeShellArgs args}
  '';
in
{
  imports = [ ../../modules/magpie/options.nix ];

  config = lib.mkIf cfg.enable {
    launchd.user.agents.magpie = {
      managedBy = "services.magpie.enable";
      serviceConfig = {
        ProgramArguments = [ (toString start) ];
        EnvironmentVariables = { MAGPIE_ADDR = cfg.listenAddress; } // cfg.environment;
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 10;
        Umask = 63;
        ProcessType = "Background";
      };
    };
  };
}
