{ pkgs, ... }:
let
  nur-packages = import ../default.nix { inherit pkgs; };
  packages = builtins.removeAttrs nur-packages [
    "lib"
    "modules"
    "overlays"
  ];
in
{
  imports = [
    ./agy-remote-control
    ./caddy
    ./cloudflare-dynamic-dns
    ./lego-acme
    ./mcp-nixos
    ./syncthing
    ./scanocr-server
    ./magpie
    ./pod-hub
  ];
  nixpkgs.overlays = [
    (final: prev: packages)
  ];
}
