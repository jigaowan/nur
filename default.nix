# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{
  pkgs ? import <nixpkgs> { },
}:
let
  allPkgs = pkgs // myPkgs;
  callPackage =
    path: overrides:
    let
      f = import path;
    in
    f ((builtins.intersectAttrs (builtins.functionArgs f) allPkgs) // overrides);
  myPkgs = rec {
    # The `lib`, `modules`, and `overlay` names are special
    lib = pkgs.lib // import ./lib { inherit pkgs; }; # functions
    modules = import ./modules; # NixOS modules
    overlays = import ./overlays; # nixpkgs overlays

    sources = callPackage ./_sources/generated.nix { };

    snell-server = callPackage ./pkgs/snell-server { };
    anytls-go = callPackage ./pkgs/anytls-go { };
    trojan-go = callPackage ./pkgs/trojan-go { };
    awakened-poe-trade = pkgs.lib.callPackageWith allPkgs ./pkgs/awakened-poe-trade { };
    exiled-exchange-2 = pkgs.lib.callPackageWith allPkgs ./pkgs/exiled-exchange-2 { };
    path-of-building = callPackage ./pkgs/path-of-building { };
    duckstation = callPackage ./pkgs/duckstation { };
    proton-cachyos = callPackage ./pkgs/proton-cachyos { };
    proton-cachyos-x86_64-v3 = callPackage ./pkgs/proton-cachyos {
      variant = "x86_64-v3";
    };
    proton-wineland = callPackage ./pkgs/proton-wineland { };
    proton-wineland-x86_64-v3 = callPackage ./pkgs/proton-wineland {
      variant = "x86_64-v3";
    };
    misskey = callPackage ./pkgs/misskey { };
    scanocr-client = callPackage ./pkgs/scanocr-client { };
    scanocr-server = callPackage ./pkgs/scanocr-server { };
    simslim = callPackage ./pkgs/simslim { };
    magpie-cli = callPackage ./pkgs/magpie-cli { };
    magpie = callPackage ./pkgs/magpie { };
  };
in
myPkgs
