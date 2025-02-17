# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> { } }:

{
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  snell-server = pkgs.callPackage ./pkgs/snell-server { };
  trojan-go = pkgs.callPackage ./pkgs/trojan-go { };
  awakened-poe-trade = pkgs.callPackage ./pkgs/awakened-poe-trade { };
  exiled-exchange-2 = pkgs.callPackage ./pkgs/exiled-exchange-2 { };
  protonhax = pkgs.callPackage ./pkgs/protonhax { };
  misskey = pkgs.callPackage ./pkgs/misskey { };

}
