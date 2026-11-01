{ config, lib, pkgs, utils, ... }:
let
  cfg = config.services.magpie;
  args = [ (lib.getExe cfg.package) "serve" ]
    ++ lib.optional cfg.web.enable "--web=${cfg.web.listenAddress}"
    ++ cfg.extraArgs;
  start = pkgs.writeShellScript "magpie-start" ''
    ${lib.optionalString (cfg.web.keyFile != null) ''
      MAGPIE_WEB_KEY=$(< "$CREDENTIALS_DIRECTORY/magpie-web-key")
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
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    users.users.magpie = {
      isSystemUser = true;
      group = "magpie";
      home = "/var/lib/magpie";
    };
    users.groups.magpie = { };

    systemd.services.magpie = {
      description = "Magpie gateway";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = { HOME = "/var/lib/magpie"; MAGPIE_ADDR = cfg.listenAddress; }
        // cfg.environment;
      serviceConfig = {
        User = "magpie";
        Group = "magpie";
        StateDirectory = "magpie";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/magpie";
        ExecStart = utils.escapeSystemdExecArgs [ (toString start) ];
        Restart = "on-failure";
        RestartSec = 10;
        UMask = "0077";
      } // lib.optionalAttrs (cfg.web.keyFile != null) {
        LoadCredential = "magpie-web-key:${cfg.web.keyFile}";
      };
    };
  };
}
