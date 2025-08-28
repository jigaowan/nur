{
  lib,
  stdenv,
  unzip,
  fetchurl,
  ...
}:
stdenv.mkDerivation rec {
  pname = "path-of-building";
  version = "2.56.0";
  src = fetchurl {
    url = "https://github.com/PathOfBuildingCommunity/PathOfBuilding/releases/download/v${version}/PathOfBuildingCommunity-Portable.zip";
    sha256 = "sha256-TEr5cLlP5px1PS5W3KtLnVFHhrH/OkhTFYjC4DvqFJg=";
  };
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
