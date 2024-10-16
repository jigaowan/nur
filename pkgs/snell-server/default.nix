{ lib, stdenv, unzip, fetchurl, autoPatchelfHook, glibc, ... }:
stdenv.mkDerivation rec {
  pname = "snell-server";
  version = "4.1.1";
  src = if stdenv.hostPlatform.system == "x86_64-linux" then
    fetchurl {
      url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-amd64.zip";
      sha256 = "sha256-zCJxt5x1BoiLNOZR6HQbOqf8fV9gqmXvi7CW8zE6GTs=";
    }
  else if stdenv.hostPlatform.system == "aarch64-linux" then
    fetchurl {
      url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-aarch64.zip";
      sha256 = "sha256-ONTNwD3Ns2CK+FlN+D4XlSZRZ/r8XYAvgVFIkIkC11g=";
    }
  else
    throw "Unsupported architecture: ${stdenv.hostPlatform.system}";
  nativeBuildInputs = [ unzip autoPatchelfHook ];
  buildInputs = [ glibc ];
  unpackPhase = ''
    unzip $src
  '';
  installPhase = ''
    install -Dm755 snell-server $out/bin/snell-server
  '';
  meta = with lib; {
    homepage = "https://nssurge.com";
    platforms = platforms.linux;
  };
}
