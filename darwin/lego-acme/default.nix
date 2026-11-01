{ config, lib, pkgs, ... }:
let
  cfg = config.services.lego-acme;
  certModule = { name, config, ... }: {
    options = {
      domain = lib.mkOption { type = lib.types.strMatching "[A-Za-z0-9.*-]+"; };
      email = lib.mkOption { type = lib.types.str; };
      tokenFile = lib.mkOption { type = lib.types.str; };
      server = lib.mkOption { type = lib.types.str; };
      interval = lib.mkOption { type = lib.types.ints.positive; default = 86400; };
      stateDir = lib.mkOption { type = lib.types.strMatching "/.*"; default = "/var/lib/lego-acme/${name}"; };
    };
  };
  jobFor = name: cert:
    let
      domainFile = lib.replaceStrings [ "*" ] [ "_" ] cert.domain;
      run = pkgs.writeShellScript "lego-acme-${name}" ''
        set -eu
        umask 077
        /usr/bin/install -d -m 0700 ${lib.escapeShellArg cert.stateDir}
        export CF_DNS_API_TOKEN_FILE=${lib.escapeShellArg cert.tokenFile}
        if [ -s ${lib.escapeShellArg "${cert.stateDir}/certificates/${domainFile}.crt"} ]; then
          action=renew
        else
          action=run
        fi
        exec ${lib.getExe cfg.package} --accept-tos --path ${lib.escapeShellArg cert.stateDir} \
          --email ${lib.escapeShellArg cert.email} --server ${lib.escapeShellArg cert.server} \
          --dns cloudflare --domains ${lib.escapeShellArg cert.domain} "$action"
      '';
    in {
      command = "${run}";
      serviceConfig = {
        RunAtLoad = false;
        StartInterval = cert.interval;
        ProcessType = "Background";
        StandardOutPath = "/var/log/lego-acme-${name}.log";
        StandardErrorPath = "/var/log/lego-acme-${name}.log";
      };
    };
in {
  options.services.lego-acme = {
    package = lib.mkPackageOption pkgs "lego" { };
    certs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule certModule);
      default = { };
      description = "Cloudflare DNS-01 certificates managed by lego on Darwin.";
    };
  };
  config = lib.mkIf (cfg.certs != { }) {
    launchd.daemons = lib.mapAttrs' (name: cert: lib.nameValuePair "lego-acme-${name}" (jobFor name cert)) cfg.certs;
    system.activationScripts.postActivation.text = lib.mkOrder 2000 (lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: _: ''
        /bin/launchctl kickstart ${lib.escapeShellArg "system/org.nixos.lego-acme-${name}"}
      '') cfg.certs
    ));
  };
}
