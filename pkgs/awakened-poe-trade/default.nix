{
  lib,
  appimageTools,
  fetchurl,
  ...
}:
let
  pname = "awakened-poe-trade";
  version = "3.27.102";
  src = fetchurl {
    url = "https://github.com/SnosMe/awakened-poe-trade/releases/download/v${version}/Awakened-PoE-Trade-${version}.AppImage";
    hash = "sha256-yisw7bc/dfgxcqxbqKVJOi6aG7HpvrFDIThBaD0kApk=";
  };
  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 rec {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/awakened-poe-trade.desktop $out/share/applications/awakened-poe-trade.desktop
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/awakened-poe-trade.png \
      $out/share/icons/hicolor/512x512/apps/awakened-poe-trade.png
    substituteInPlace $out/share/applications/awakened-poe-trade.desktop \
      --replace-fail 'Exec=AppRun --sandbox %U' 'Exec=${pname} --sandbox --listen=localhost:9128 --no-overlay %U'
  '';

  meta = with lib; {
    homepage = "https://snosme.github.io/awakened-poe-trade";
    description = "💲 🔨 Path of Exile trading app for price checking";
    platforms = platforms.linux;
  };
}
