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
    ./caddy
    ./cloudflare-dynamic-dns
    ./mcp-nixos
    ./syncthing
    ./scanocr-server
    ./magpie
  ];
  nixpkgs.overlays = [
    (final: prev: packages)
  ];
}
