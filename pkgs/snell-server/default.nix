{ lib, stdenv, unzip, upx, glibc, fetchurl,... }:
stdenv.mkDerivation rec {
  pname = "snell-server";
  version = "5.0.1";
  src = if stdenv.hostPlatform.system == "x86_64-linux" then
    fetchurl {
      url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-amd64.zip";
      sha256 = "sha256-m+ocK541tzsxY0hWwE0Yw5MHK55dzeajJ4HYuPkIxTk=";
    }
  else if stdenv.hostPlatform.system == "aarch64-linux" then
    fetchurl {
      url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-aarch64.zip";
      sha256 = "sha256-LxeL9axGjOGhMEVO+kCgYD+75OR+zEiAqYn0q8f4JM8=";
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
