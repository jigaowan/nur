{
  lib,
  appimageTools,
  sources,
  launchArgs ? [ ],
  ...
}:
let
  inherit (sources.Exiled-Exchange-2) pname version src;
  desktopExec = lib.concatStringsSep " " ([ "Exec=${pname}" ] ++ launchArgs ++ [ "%U" ]);
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
      --replace-fail 'Exec=AppRun --sandbox %U' ${lib.escapeShellArg desktopExec}
  '';

  meta = with lib; {
    homepage = "https://kvan7.github.io/Exiled-Exchange-2";
    description = "Path of Exile 2 trading app for price checking (aka EE2)";
    platforms = platforms.linux;
  };
}
