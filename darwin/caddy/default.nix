{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.caddy;
  inherit (lib)
    mkIf
    mkOption
    types
    optionalString
    escapeShellArg
    escapeShellArgs
    ;
  defaultUser = "_caddy";
  configPath = "/etc/caddy/caddy_config";
  absolutePath = types.strMatching "/.*";
  settingsFormat = pkgs.formats.json { };

  generatedConfig =
    if cfg.settings != { } then
      settingsFormat.generate "caddy.json" cfg.settings
    else
      pkgs.writeText "Caddyfile" ''
        {
          ${optionalString (cfg.email != null) "email ${cfg.email}"}
          ${optionalString (cfg.acmeCA != null) "acme_ca ${cfg.acmeCA}"}
          ${optionalString (cfg.httpPort != null) "http_port ${toString cfg.httpPort}"}
          ${optionalString (cfg.httpsPort != null) "https_port ${toString cfg.httpsPort}"}
          log {
            ${cfg.logFormat}
          }
          ${cfg.globalConfig}
        }
        ${cfg.extraConfig}
        ${lib.concatMapStringsSep "\n" (host: ''
          ${lib.concatStringsSep " " ([ host.hostName ] ++ host.serverAliases)} {
            ${optionalString (
              host.listenAddresses != [ ]
            ) "bind ${lib.concatStringsSep " " host.listenAddresses}"}
            ${optionalString (host.logFormat != null) ''
              log {
                ${host.logFormat}
              }
            ''}
            ${host.extraConfig}
          }
        '') (lib.attrValues cfg.virtualHosts)}
      '';

  configArgs = [
    "--config"
    configPath
  ]
  ++ lib.optionals (cfg.adapter != null) [
    "--adapter"
    cfg.adapter
  ];
  envArgs = lib.optionals (cfg.environmentFile != null) [
    "--envfile"
    cfg.environmentFile
  ];
  environment = {
    HOME = cfg.dataDir;
    XDG_DATA_HOME = "${cfg.dataDir}/.local/share";
    XDG_CONFIG_HOME = "${cfg.dataDir}/.config";
  };
  exportEnvironment = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "export ${name}=${escapeShellArg value}") environment
  );
  run = pkgs.writeShellScript "caddy-start" ''
    set -eu
    ${optionalString (!cfg.enableReload) "# Restart when the configuration changes: ${cfg.configFile}"}
    ${exportEnvironment}
    exec ${lib.getExe cfg.package} run ${
      escapeShellArgs (configArgs ++ envArgs ++ lib.optional cfg.resume "--resume")
    }
  '';
  reload = pkgs.writeShellScriptBin "caddy-reload" ''
    set -eu
    ${exportEnvironment}
    ${
      if cfg.environmentFile != null && cfg.adapter != null then
        ''
          # reload has no --envfile flag. Adapt privately so {$VAR} substitutions
          # use the current credentials without evaluating the file as shell code.
          umask 077
          reload_dir=$(/usr/bin/mktemp -d "''${TMPDIR:-/tmp}/caddy-reload.XXXXXX")
          trap '/bin/rm -rf "$reload_dir"' EXIT
          ${lib.getExe cfg.package} adapt ${
            escapeShellArgs (configArgs ++ envArgs)
          } > "$reload_dir/config.json"
          ${lib.getExe cfg.package} reload --config "$reload_dir/config.json" --force
        ''
      else
        ''
          exec ${lib.getExe cfg.package} reload ${escapeShellArgs (configArgs ++ [ "--force" ])}
        ''
    }
  '';
  label = config.launchd.daemons.caddy.serviceConfig.Label;
  plist = config.environment.launchDaemons."${label}.plist".source;
in
{
  options.services.caddy = {
    enable = lib.mkEnableOption "the Caddy web server";
    package = lib.mkPackageOption pkgs "caddy" { };
    user = mkOption {
      type = types.str;
      default = defaultUser;
      description = "Service user. The default _caddy account is created automatically; custom identities must already exist.";
    };
    group = mkOption {
      type = types.str;
      default = defaultUser;
      description = "Service group. Set both user and group when using a custom identity.";
    };
    dataDir = mkOption {
      type = absolutePath;
      default = "/var/lib/caddy";
      description = ''
        Persistent service home, created with mode 0750 and the service identity.
        Certificates are stored in .local/share/caddy and autosave.json in .config/caddy.
        Existing contents are not recursively chowned.
      '';
    };
    logDir = mkOption {
      type = absolutePath;
      default = "/var/log/caddy";
      description = "Directory created with mode 0750 for Caddy logs, owned by the service identity.";
    };
    logFormat = mkOption {
      type = types.lines;
      default = ''
        output file ${builtins.toJSON "${cfg.logDir}/caddy.log"}
        level ERROR
      '';
      defaultText = lib.literalExpression ''"output file <logDir>/caddy.log\nlevel ERROR"'';
      description = "Global Caddy logger configuration. Caddy rotates its file output automatically.";
    };
    configFile = mkOption {
      type = types.path;
      default = generatedConfig;
      defaultText = "Configuration generated from services.caddy options";
      description = ''
        Caddy configuration linked at /etc/caddy/caddy_config. Overrides generated
        configuration. Use a quoted absolute runtime path for a file outside the Nix store.
      '';
    };
    adapter = mkOption {
      type = types.nullOr types.str;
      default = if cfg.configFile == generatedConfig && cfg.settings != { } then null else "caddyfile";
      defaultText = "null for generated JSON, otherwise caddyfile";
      description = "Configuration adapter. Set null for a custom native JSON configFile.";
    };
    settings = mkOption {
      type = settingsFormat.type;
      default = { };
      description = "Native JSON configuration. When non-empty, replaces all generated Caddyfile options.";
    };
    globalConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional lines inside the generated Caddyfile global options block.";
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional top-level Caddyfile configuration, such as snippets or sites.";
    };
    virtualHosts = mkOption {
      default = { };
      description = "Declarative Caddyfile virtual hosts.";
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }: {
            options = {
              hostName = mkOption {
                type = types.str;
                default = name;
                description = "Canonical site address.";
              };
              serverAliases = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Additional site addresses.";
              };
              listenAddresses = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Interfaces passed to the bind directive.";
              };
              logFormat = mkOption {
                type = types.nullOr types.lines;
                default = "output file ${builtins.toJSON "${cfg.logDir}/access-${lib.replaceStrings [ "/" " " ] [ "_" "_" ] config.hostName}.log"}";
                defaultText = "File output under services.caddy.logDir";
                description = "Access logger configuration. Set null to omit the log directive.";
              };
              extraConfig = mkOption {
                type = types.lines;
                default = "";
                description = "Directives inside the virtual host, including reverse_proxy or tls.";
              };
            };
          }
        )
      );
    };
    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Email address for Caddy's ACME accounts.";
    };
    acmeCA = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "ACME directory URL. Null preserves Caddy's default issuers and fallback.";
    };
    httpPort = mkOption {
      type = types.nullOr types.port;
      default = 80;
      description = "Global HTTP port. Null omits the directive; it does not disable HTTP.";
    };
    httpsPort = mkOption {
      type = types.nullOr types.port;
      default = 443;
      description = "Global HTTPS/HTTP3 port. Null omits the directive; it does not disable HTTPS.";
    };
    environmentFile = mkOption {
      type = types.nullOr absolutePath;
      default = null;
      example = "/run/agenix/caddy.env";
      description = ''
        Runtime KEY=VALUE file, readable by the service user. Parsed by Caddy's
        --envfile on start and adapt before reload, not by a shell or systemd.
        Its contents are never read by Nix. Use {$VARIABLE} in the Caddyfile.
        Runtime {env.VARIABLE} placeholders, including native JSON settings,
        retain the running process's environment until a restart.
      '';
    };
    enableReload = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Reload a running service during activation if its launchd plist is unchanged.
        Requires Caddy's admin API. Reload errors fail activation and preserve the
        running configuration. Package, identity or other plist changes restart
        the service. Set false for admin off or when changing the admin address.
      '';
    };
    resume = mkOption {
      type = types.bool;
      default = false;
      description = "Prefer autosaved configuration on startup. Requires enableReload = false for API-managed deployments.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.user == defaultUser) == (cfg.group == defaultUser);
        message = "services.caddy.user and group must both use _caddy, or both specify an existing custom identity.";
      }
      {
        assertion = !(cfg.resume && cfg.enableReload);
        message = "services.caddy.resume requires enableReload = false so activation does not overwrite API-managed configuration.";
      }
      {
        assertion =
          cfg.configFile != generatedConfig
          || cfg.adapter == (if cfg.settings != { } then null else "caddyfile");
        message = "services.caddy.adapter must match the generated configuration; provide configFile to use another adapter.";
      }
    ];

    ids.uids._caddy = lib.mkDefault 537;
    ids.gids._caddy = lib.mkDefault 537;
    users.knownUsers = mkIf (cfg.user == defaultUser) [ defaultUser ];
    users.knownGroups = mkIf (cfg.group == defaultUser) [ defaultUser ];
    users.users = mkIf (cfg.user == defaultUser) {
      _caddy = {
        uid = config.ids.uids._caddy;
        gid = config.ids.gids._caddy;
        home = cfg.dataDir;
        shell = "/usr/bin/false";
        description = "Caddy web server";
      };
    };
    users.groups = mkIf (cfg.group == defaultUser) {
      _caddy.gid = config.ids.gids._caddy;
    };

    environment.systemPackages = [ cfg.package ] ++ lib.optional cfg.enableReload reload;
    environment.etc."caddy/caddy_config".source = cfg.configFile;

    launchd.daemons.caddy = {
      command = run;
      serviceConfig = {
        UserName = cfg.user;
        GroupName = cfg.group;
        WorkingDirectory = cfg.dataDir;
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 10;
        ExitTimeOut = 30;
        ProcessType = "Standard";
        Umask = 23; # 0027 in decimal, as required by launchd's integer field.
        StandardOutPath = "${cfg.logDir}/stdout.log";
        StandardErrorPath = "${cfg.logDir}/stderr.log";
      };
    };

    # This runs after users, groups and /etc, but before launchd opens log files.
    system.activationScripts.launchd.text = lib.mkBefore (
      import ./activation.nix {
        inherit
          lib
          cfg
          label
          plist
          ;
        reloadCommand = "/usr/bin/sudo -u ${escapeShellArg cfg.user} -g ${escapeShellArg cfg.group} -- ${reload}/bin/caddy-reload";
      }
    );
  };
}
