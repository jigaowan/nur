{ nixpkgs, darwin, system ? "aarch64-darwin" }:
let
  pkgs = import nixpkgs { inherit system; };
  c = (import (darwin + "/eval-config.nix") {
    inherit (pkgs) lib;
    modules = [
      ../.
      {
        nixpkgs.pkgs = pkgs;
        nix.enable = false;
        system.stateVersion = 5;
        services.lego-acme.certs.home = {
          domain = "*.example.test";
          email = "admin@example.test";
          tokenFile = "/run/secrets/test";
          server = "https://example.test/directory";
          group = "_caddy";
          reloadServices = [ "org.nixos.caddy" ];
        };
      }
    ];
  }).config;
in
assert c.services.lego-acme.certs.home.directory == "/var/lib/acme/home";
assert c.services.lego-acme.certs.home.group == "_caddy";
assert c.launchd.daemons.lego-acme-home.serviceConfig.StartInterval == 86400;
assert c.launchd.daemons.lego-acme-home.serviceConfig.RunAtLoad == false;
assert pkgs.lib.all (a: a.assertion) c.assertions;
{ passed = true; }
