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
    ./mcp-nixos
    ./syncthing
    ./scanocr
  ];
  nixpkgs.overlays = [
    (final: prev: packages)
  ];
}
