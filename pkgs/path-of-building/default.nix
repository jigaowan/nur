{
  lib,
  stdenv,
  unzip,
  sources,
  ...
}:
stdenv.mkDerivation rec {
  inherit (sources.path-of-building) pname version src;
  nativeBuildInputs = [
    unzip
  ];
  unpackPhase = ''
    unzip $src
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r ./* $out/
    runHook postInstall
  '';
  meta = with lib; {
    homepage = "https://pathofbuilding.community";
    platforms = platforms.linux;
  };
}
