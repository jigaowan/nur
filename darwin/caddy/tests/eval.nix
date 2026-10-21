{
  nixpkgs,
  darwin,
  system ? "aarch64-darwin",
}:
let
  pkgs = import nixpkgs { inherit system; };
  inherit (pkgs) lib;
  eval =
    extra:
    (import (darwin + "/eval-config.nix") {
      inherit lib;
      modules = [
        ../.
        {
          nixpkgs.pkgs = pkgs;
          nix.enable = false;
          system.stateVersion = 5;
        }
        extra
      ];
    }).config;
  enabled =
    extra:
    eval {
      services.caddy = {
        enable = true;
      }
      // extra;
    };
  base = enabled { };
  changed = enabled {
    virtualHosts."http://example.test".extraConfig = "respond changed";
  };
  restart = enabled { enableReload = false; };
  restartChanged = enabled {
    enableReload = false;
    virtualHosts."http://example.test".extraConfig = "respond changed";
  };
  native = enabled {
    settings = {
      apps.http.servers.test = {
        listen = [ "127.0.0.1:8080" ];
      };
    };
  };
  custom = enabled {
    user = "testuser";
    group = "staff";
  };
  runtime = enabled {
    environmentFile = "/run/secrets/never-read.env";
    configFile = "/etc/caddy/external.json";
    adapter = null;
  };
  disabled = eval { };
  command = c: toString c.launchd.daemons.caddy.command;
  valid = c: lib.all (a: a.assertion) c.assertions;
  fixture = enabled {
    logDir = "/tmp/caddy test logs";
    environmentFile = "/run/secrets/never-read.env";
    globalConfig = ''
      admin 127.0.0.1:{$CADDY_TEST_ADMIN_PORT}
      auto_https off
    '';
    logFormat = lib.mkForce "output stderr";
    virtualHosts."http://127.0.0.1:{$CADDY_TEST_PORT}" = {
      listenAddresses = [ "127.0.0.1" ];
      logFormat = null;
      extraConfig = ''
        handle /proxy {
          reverse_proxy 127.0.0.1:{$CADDY_TEST_UPSTREAM_PORT}
        }
        handle {
          respond "{$CADDY_TEST_RESPONSE}"
        }
      '';
    };
  };
  dnsFixture = enabled {
    globalConfig = ''
      acme_dns cloudflare {$ACME_TOKEN}
      dynamic_dns {
        provider cloudflare {
          api_token {$DDNS_TOKEN}
        }
        domains {
          example.com server
        }
        versions ipv6
        ip_source interface en0
      }
    '';
    virtualHosts."proxy.example.com".extraConfig = "reverse_proxy localhost:8080";
  };
  loggingFixture = enabled {
    logDir = "/tmp/caddy test logs";
    virtualHosts."http://example.test" = {
      hostName = "http://primary.test";
      serverAliases = [ "http://alias.test" ];
      listenAddresses = [
        "127.0.0.1"
        "::1"
      ];
      extraConfig = "respond ok";
    };
  };
  results = {
    enabledValid = valid base;
    disabledIsInert =
      !(disabled.launchd.daemons ? caddy)
      && !(disabled.users.users ? _caddy)
      && !(disabled.environment.etc ? "caddy/caddy_config");
    createsIdentity = base.users.users._caddy.uid == 537 && base.users.groups._caddy.gid == 537;
    customIdentityValid =
      valid custom && !(custom.users.users ? _caddy) && !(custom.users.groups ? _caddy);
    partialIdentityRejected =
      !(valid (enabled {
        user = "testuser";
      }));
    resumeReloadRejected =
      !(valid (enabled {
        resume = true;
      }));
    resumeWithoutReloadValid = valid (enabled {
      resume = true;
      enableReload = false;
    });
    reloadKeepsCommand = command base == command changed;
    reloadKeepsPlist =
      base.environment.launchDaemons."org.nixos.caddy.plist".text
      == changed.environment.launchDaemons."org.nixos.caddy.plist".text;
    packageChangeRestarts =
      command base != command (enabled {
        package = pkgs.caddy.overrideAttrs { pname = "caddy-test-package"; };
      });
    restartChangesCommand = command restart != command restartChanged;
    configActuallyChanges =
      toString base.services.caddy.configFile != toString changed.services.caddy.configFile;
    jsonOmitsAdapter = native.services.caddy.adapter == null && valid native;
    wrongGeneratedAdapterRejected =
      !(valid (enabled {
        adapter = "nginx";
      }));
    customJSONValid = valid runtime && runtime.services.caddy.adapter == null;
    customAdapterValid = valid (enabled {
      configFile = "/etc/custom.conf";
      adapter = "nginx";
    });
    runtimeSecretsNotRead = runtime.services.caddy.environmentFile == "/run/secrets/never-read.env";
    bootAndCrashRecovery =
      base.launchd.daemons.caddy.serviceConfig.RunAtLoad
      && !base.launchd.daemons.caddy.serviceConfig.KeepAlive.SuccessfulExit;
    serviceIdentity =
      base.launchd.daemons.caddy.serviceConfig.UserName == "_caddy"
      && base.launchd.daemons.caddy.serviceConfig.GroupName == "_caddy";
    restrictiveUmask = base.launchd.daemons.caddy.serviceConfig.Umask == 23;
    aggregateExportsModule = lib.elem ../. (import ../../default.nix { inherit pkgs; }).imports;
    flakeExportsModule =
      ((import ../../../flake.nix).outputs {
        self = { };
        nixpkgs = { inherit lib; };
      }).darwinModules.caddy == ../.;
  };
  activation =
    enableReload:
    import ../activation.nix {
      inherit lib;
      cfg = {
        inherit enableReload;
        user = "testuser";
        group = "staff";
        dataDir = "/tmp/caddy-data";
        logDir = "/tmp/caddy-logs";
      };
      label = "org.nixos.caddy";
      plist = "/tmp/caddy-new.plist";
      reloadCommand = "mock-reload";
    };
in
{
  inherit results;
  passed =
    assert lib.all (x: x) (lib.attrValues results);
    builtins.length (lib.attrNames results);
  artifacts =
    assert lib.all (x: x) (lib.attrValues results);
    pkgs.linkFarm "caddy-darwin-test-artifacts" {
      Caddyfile = fixture.services.caddy.configFile;
      "dns.Caddyfile" = dnsFixture.services.caddy.configFile;
      "logging.Caddyfile" = loggingFixture.services.caddy.configFile;
      "caddy.json" = native.services.caddy.configFile;
      "start.sh" = fixture.launchd.daemons.caddy.command;
      "reload.sh" = "${
        lib.findFirst (p: p.name or "" == "caddy-reload") null fixture.environment.systemPackages
      }/bin/caddy-reload";
      "caddy.plist" = base.environment.launchDaemons."org.nixos.caddy.plist".source;
      "activation.sh" = pkgs.writeText "activation.sh" (activation true);
      "activation-no-reload.sh" = pkgs.writeText "activation-no-reload.sh" (activation false);
      caddy = lib.getExe pkgs.caddy;
    };
}
