{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.pod-hub;
  defaultUser = "_pod-hub";
  defaultGroup = defaultUser;
  configFile = import ../../modules/pod-hub/config.nix { inherit lib pkgs cfg; };

  envLoader = pkgs.writeText "pod-hub-env-exec.py" ''
    import os
    import sys

    env_path = sys.argv[1]
    cmd = sys.argv[2:]

    with open(env_path, "r", encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.strip()
            if not line or line.startswith(("#", ";")):
                continue
            if line.startswith("export ") and "=" in line:
                line = line[7:].lstrip()
            if "=" not in line:
                raise SystemExit(f"{env_path}:{lineno}: invalid environment line")
            key, val = line.split("=", 1)
            key = key.strip()
            val = val.strip()
            if not key:
                raise SystemExit(f"{env_path}:{lineno}: empty variable name")
            if len(val) >= 2 and val[0] == "'" and val[-1] == "'":
                val = val[1:-1]
            elif len(val) >= 2 and val[0] == '"' and val[-1] == '"':
                inner = val[1:-1]
                out = []
                i = 0
                while i < len(inner):
                    if inner[i] == "\\" and i + 1 < len(inner):
                        nxt = inner[i + 1]
                        out.append({"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}.get(nxt, "\\" + nxt))
                        i += 2
                    else:
                        out.append(inner[i])
                        i += 1
                val = "".join(out)
            os.environ[key] = val

    os.execv(cmd[0], cmd)
  '';

  programArguments =
    if cfg.environmentFile != null then
      [
        "${pkgs.python3}/bin/python3"
        "${envLoader}"
        cfg.environmentFile
        (lib.getExe cfg.package)
        "serve"
      ]
    else
      [
        (lib.getExe cfg.package)
        "serve"
      ];
in
{
  imports = [ ../../modules/pod-hub/options.nix ];

  options.services.pod-hub = {
    user = lib.mkOption {
      type = lib.types.str;
      default = defaultUser;
      description = "Service user. The default _pod-hub account is created automatically; custom identities must already exist.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = defaultGroup;
      description = "Service group. Set both user and group when using a custom identity.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/pod-hub";
      description = "Absolute directory created with mode 0750 for Pod Hub launchd logs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.user == defaultUser) == (cfg.group == defaultGroup);
        message = "services.pod-hub.user and services.pod-hub.group must both use _pod-hub, or both specify an existing custom macOS identity.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.logDir;
        message = "services.pod-hub.logDir must be an absolute path.";
      }
    ];

    ids.uids.${defaultUser} = lib.mkDefault 538;
    ids.gids.${defaultGroup} = lib.mkDefault 538;
    users.knownUsers = lib.mkIf (cfg.user == defaultUser) [ defaultUser ];
    users.knownGroups = lib.mkIf (cfg.group == defaultGroup) [ defaultGroup ];
    users.users = lib.mkIf (cfg.user == defaultUser) {
      ${defaultUser} = {
        uid = config.ids.uids.${defaultUser};
        gid = config.ids.gids.${defaultGroup};
        home = cfg.stateDir;
        shell = "/usr/bin/false";
        description = "Pod Hub podcast service";
      };
    };
    users.groups = lib.mkIf (cfg.group == defaultGroup) {
      ${defaultGroup} = {
        gid = config.ids.gids.${defaultGroup};
        description = "Pod Hub podcast service group";
      };
    };

    environment.systemPackages = [ cfg.package ];

    launchd.daemons.pod-hub = {
      environment = {
        HOME = cfg.stateDir;
        PODHUB_CONFIG = "${configFile}";
      };
      serviceConfig = {
        ProgramArguments = programArguments;
        UserName = cfg.user;
        GroupName = cfg.group;
        WorkingDirectory = cfg.stateDir;
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 10;
        ExitTimeOut = 30;
        ProcessType = "Background";
        Umask = 18; # 0022 in decimal; stateDir/logDir stay 0750 while outputDir files stay readable.
        StandardOutPath = "${cfg.logDir}/stdout.log";
        StandardErrorPath = "${cfg.logDir}/stderr.log";
      };
    };

    system.activationScripts.launchd.text = lib.mkBefore ''
      /usr/bin/install -d -m 0750 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} \
        ${lib.escapeShellArg cfg.stateDir} ${lib.escapeShellArg cfg.logDir}
      /usr/bin/install -d -m 0755 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} \
        ${lib.escapeShellArg cfg.outputDir}
    '';
  };
}
