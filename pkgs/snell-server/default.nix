{
  lib,
  stdenv,
  unzip,
  glibc,
  fetchurl,
  ...
}:
stdenv.mkDerivation rec {
  pname = "snell-server";
  version = "6.0.0";
  src =
    if stdenv.hostPlatform.system == "x86_64-linux" then
      fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-amd64.zip";
        sha256 = "sha256-ipxEY8qHz6Xqo3xq8NN6uT6idaoSORmFuyo3XKOr1/I=";
      }
    else if stdenv.hostPlatform.system == "aarch64-linux" then
      fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-aarch64.zip";
        sha256 = "sha256-oLKRXLx33Duvj6Bp50HCCAjYoQw6ipPnCaClgGRcO9c=";
      }
    else
      throw "Unsupported architecture: ${stdenv.hostPlatform.system}";
  nativeBuildInputs = [ unzip ];
  buildInputs = [ glibc ];
  unpackPhase = ''
    unzip $src
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 snell-server $out/bin/snell-server
    runHook postInstall
  '';
  preFixup =
    let
      libPath = lib.makeLibraryPath [
        glibc
        stdenv.cc.cc.lib
      ];
    in
    ''
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${libPath}" \
        $out/bin/snell-server
    '';
  meta = with lib; {
    homepage = "https://nssurge.com";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "snell-server";
  };
}
