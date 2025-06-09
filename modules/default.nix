{ pkgs, ... }:
let
  nur-packages = import ../default.nix { inherit pkgs; };
  packages = builtins.removeAttrs nur-packages [ "lib" "modules" "overlays" ];
in
{
  disabledModules = [ "services/networking/sing-box.nix" ];
  imports = [
    ./hysteria
    ./snell-server
    ./sing-box
    ./trojan-go
  ];
  nixpkgs.overlays = [
    (final: prev: packages)
  ];
}
