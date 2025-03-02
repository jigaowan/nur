{ lib, appimageTools, fetchurl, ... }:
let
  pname = "Exiled-Exchange-2";
  version = "0.8.0";
  src = fetchurl {
    url = "https://github.com/Kvan7/Exiled-Exchange-2/releases/download/v${version}/Exiled-Exchange-2-${version}.AppImage";
    hash = "sha256-TV96mq5qN+bkKh3JPK/sr9Ensu6iHLBhxz9QBfq38ZE=";
  };
  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 rec {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/exiled-exchange-2.desktop $out/share/applications/exiled-exchange-2.desktop
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/exiled-exchange-2.png \
      $out/share/icons/hicolor/512x512/apps/exiled-exchange-2.png
    substituteInPlace $out/share/applications/exiled-exchange-2.desktop \
      --replace-fail 'Exec=AppRun --sandbox %U' 'Exec=${pname} --sandbox --listen=localhost:9129 --no-overlay %U'
  '';

  meta = with lib; {
    homepage = "https://kvan7.github.io/Exiled-Exchange-2";
    description = "Path of Exile 2 trading app for price checking (aka EE2)";
    platforms = platforms.linux;
  };
}
