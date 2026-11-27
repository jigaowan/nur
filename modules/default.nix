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
  disabledModules = [ "services/networking/sing-box.nix" ];
  imports = [
    ./agy-remote-control
    ./hysteria
    ./anytls-go
    ./snell-server
    ./sing-box
    ./trojan-go
    ./misskey-hub
    ./mcp-nixos
    ./scanocr-client
    ./magpie
    ./pod-hub
  ];
  nixpkgs.overlays = [
    (final: prev: packages)
  ];
}
