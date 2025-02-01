{ lib, stdenv, fetchurl, ... }:
stdenv.mkDerivation rec {
  pname = "protonhax";
  version = "1.0.5";
  src = fetchurl {
    url = "https://github.com/jcnils/protonhax/archive/refs/tags/${version}.tar.gz";
    hash = "sha256-PadyyUcwnzO+e2E8HLkjLDR3rkT7HFgf+pbLZQhJa6Q=";
  };
  installPhase = ''
    install -Dm755 protonhax $out/bin/protonhax
  '';
  meta = with lib; {
    homepage = "https://github.com/jcnils/protonhax";
    description = "Run programs inside your game proton's environment.";
    platforms = platforms.linux;
  };
}
