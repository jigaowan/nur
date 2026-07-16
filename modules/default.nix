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
    ./hysteria
    ./anytls-go
    ./snell-server
    ./sing-box
    ./trojan-go
    ./misskey-hub
    ./mcp-nixos
    ./scanocr-client
  ];
  nixpkgs.overlays = [
    (final: prev: packages)
  ];
}
