{
  description = "My personal NUR repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      legacyPackages = forAllSystems (system: import ./default.nix {
        pkgs = import nixpkgs { inherit system; };
      });
      packages = forAllSystems (system: nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) self.legacyPackages.${system});
      nixosModules = {
        default = ./modules;
        agy-remote-control = ./modules/agy-remote-control;
        pod-hub = ./modules/pod-hub;
      };
      darwinModules = {
        default = ./darwin;
        agy-remote-control = ./darwin/agy-remote-control;
        caddy = ./darwin/caddy;
        cloudflare-dynamic-dns = ./darwin/cloudflare-dynamic-dns;
        lego-acme = ./darwin/lego-acme;
        pod-hub = ./darwin/pod-hub;
      };
      overlays = { default = import ./overlay.nix; };
    };
}
