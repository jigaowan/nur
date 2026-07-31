{
  lib,
  appimageTools,
  sources,
  launchArgs ? [ ],
  ...
}:
let
  inherit (sources.awakened-poe-trade) pname version src;
  desktopExec = lib.concatStringsSep " " ([ "Exec=${pname}" ] ++ launchArgs ++ [ "%U" ]);
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
      --replace-fail 'Exec=AppRun %U' ${lib.escapeShellArg desktopExec}
  '';

  meta = with lib; {
    homepage = "https://snosme.github.io/awakened-poe-trade";
    description = "💲 🔨 Path of Exile trading app for price checking";
    platforms = platforms.linux;
  };
}
