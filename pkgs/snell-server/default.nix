{ lib, stdenv, unzip, upx, glibc, fetchurl,... }:
stdenv.mkDerivation rec {
  pname = "snell-server";
  version = "5.0.0";
  src = if stdenv.hostPlatform.system == "x86_64-linux" then
    fetchurl {
      url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-amd64.zip";
      sha256 = "sha256-iTp75PxeaVuXrLgK+aSpm5mGf4y0dnhHJaP4n6I5QOE=";
    }
  else if stdenv.hostPlatform.system == "aarch64-linux" then
    fetchurl {
      url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-aarch64.zip";
      sha256 = "sha256-dnCQMqjRBD+m8B4fu7cnFI13U0qDKT1zVkpWksOWcpI=";
    }
  else
    throw "Unsupported architecture: ${stdenv.hostPlatform.system}";
  nativeBuildInputs = [ unzip upx ];
  buildInputs = [ glibc ];
  unpackPhase = ''
    unzip $src
  '';
  installPhase = ''
    runHook preInstall
    upx -d snell-server -o snell-server.tmp
    mv snell-server.tmp snell-server
    install -Dm755 snell-server $out/bin/snell-server
    runHook postInstall
  '';
  preFixup = let
    libPath = lib.makeLibraryPath [
      glibc
      stdenv.cc.cc.lib
    ];
  in ''
    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${libPath}" \
      $out/bin/snell-server
  '';
  meta = with lib; {
    homepage = "https://nssurge.com";
    platforms = platforms.linux;
  };
}
