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
      stateDir = lib.mkOption { type = lib.types.strMatching "/.*"; default = "/var/lib/lego-acme/${name}"; description = "Private lego account and certificate state."; };
      directory = lib.mkOption { type = lib.types.str; readOnly = true; default = "/var/lib/acme/${name}"; description = "Directory containing fullchain.pem and key.pem."; };
      group = lib.mkOption { type = lib.types.str; default = "wheel"; description = "Group allowed to read the certificate and key."; };
      reloadServices = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; description = "System launchd service labels to restart after a certificate changes."; };
    };
  };
  jobFor = name: cert:
    let
      domainFile = lib.replaceStrings [ "*" ] [ "_" ] cert.domain;
      run = pkgs.writeShellScript "lego-acme-${name}" ''
        set -euo pipefail
        umask 077
        /bin/mkdir -p ${lib.escapeShellArg cert.stateDir}
        /bin/chmod 0700 ${lib.escapeShellArg cert.stateDir}
        export CF_DNS_API_TOKEN_FILE=${lib.escapeShellArg cert.tokenFile}
        if [ -s ${lib.escapeShellArg "${cert.stateDir}/certificates/${domainFile}.crt"} ]; then
          action=(renew --no-random-sleep)
        else
          action=(run)
        fi
        ${lib.getExe cfg.package} --accept-tos --path ${lib.escapeShellArg cert.stateDir} \
          --email ${lib.escapeShellArg cert.email} --server ${lib.escapeShellArg cert.server} \
          --dns cloudflare --domains ${lib.escapeShellArg cert.domain} "''${action[@]}"
        cert_file=${lib.escapeShellArg "${cert.stateDir}/certificates/${domainFile}.crt"}
        key_file=${lib.escapeShellArg "${cert.stateDir}/certificates/${domainFile}.key"}
        /usr/bin/install -d -m 0711 -o root -g wheel /var/lib/acme
        /usr/bin/install -d -m 0750 -o root -g ${lib.escapeShellArg cert.group} ${lib.escapeShellArg cert.directory}
        changed=0
        if ! /usr/bin/cmp -s "$cert_file" ${lib.escapeShellArg "${cert.directory}/fullchain.pem"} || ! /usr/bin/cmp -s "$key_file" ${lib.escapeShellArg "${cert.directory}/key.pem"}; then
          /usr/bin/install -m 0640 -o root -g ${lib.escapeShellArg cert.group} "$cert_file" ${lib.escapeShellArg "${cert.directory}/fullchain.pem"}
          /usr/bin/install -m 0640 -o root -g ${lib.escapeShellArg cert.group} "$key_file" ${lib.escapeShellArg "${cert.directory}/key.pem"}
          changed=1
        fi
        /usr/sbin/chown root:${lib.escapeShellArg cert.group} ${lib.escapeShellArg "${cert.directory}/fullchain.pem"} ${lib.escapeShellArg "${cert.directory}/key.pem"}
        /bin/chmod 0640 ${lib.escapeShellArg "${cert.directory}/fullchain.pem"} ${lib.escapeShellArg "${cert.directory}/key.pem"}
        ${lib.optionalString (cert.reloadServices != [ ]) ''
          # Only acknowledge the certificate after every requested restart succeeds.
          if [ "$changed" = 1 ] || ! /usr/bin/cmp -s "$cert_file" ${lib.escapeShellArg "${cert.stateDir}/deployed.crt"}; then
            ${lib.concatMapStringsSep "\n" (label: "/bin/launchctl kickstart -k ${lib.escapeShellArg "system/${label}"}") cert.reloadServices}
            /usr/bin/install -m 0600 "$cert_file" ${lib.escapeShellArg "${cert.stateDir}/deployed.crt"}
          fi
        ''}
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
