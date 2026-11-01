{ config, lib, pkgs, ... }:
let
  cfg = config.services.cloudflare-dynamic-dns;
  getIPv6 = pkgs.writeShellScript "cloudflare-ddns-ipv6" ''
    set -euo pipefail
    /sbin/ifconfig -L ${lib.escapeShellArg cfg.interface} | /usr/bin/awk '
      !found && $1 == "inet6" && $2 ~ /^[23][0-9a-fA-F]*:/ && $0 !~ /(^|[[:space:]])(temporary|deprecated|tentative|duplicated)([[:space:]]|$)/ {
        print $2
        found = 1
      }
      END { if (!found) exit 1 }
    '
  '';
  run = pkgs.writeShellScript "cloudflare-ddns-run" ''
    set -eu
    CFDDNS_TOKEN=$(/bin/cat ${lib.escapeShellArg cfg.tokenFile})
    export CFDDNS_TOKEN
    exec ${lib.getExe cfg.package} \
      --ipcmd ${lib.escapeShellArg (toString getIPv6)} \
      --stack ipv6 \
      ${lib.concatMapStringsSep " " (domain: "--domains ${lib.escapeShellArg domain}") cfg.domains}
  '';
in
{
  options.services.cloudflare-dynamic-dns = {
    enable = lib.mkEnableOption "Cloudflare IPv6 dynamic DNS";
    package = lib.mkPackageOption pkgs "cloudflare-dynamic-dns" { };
    interface = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9_.-]+";
      description = "Interface from which to select a global, non-temporary IPv6 address.";
    };
    domains = lib.mkOption {
      type = lib.types.nonEmptyListOf (lib.types.strMatching "[A-Za-z0-9.*-]+");
      description = "Fully qualified DNS names to update.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      description = "Runtime file containing the Cloudflare API token; readable by root.";
    };
    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Polling interval in seconds.";
    };
  };
  config = lib.mkIf cfg.enable {
    launchd.daemons.cloudflare-dynamic-dns = {
      command = "${run}";
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = cfg.interval;
        ProcessType = "Background";
        StandardErrorPath = "/var/log/cloudflare-dynamic-dns.log";
        StandardOutPath = "/var/log/cloudflare-dynamic-dns.log";
      };
    };
  };
}
