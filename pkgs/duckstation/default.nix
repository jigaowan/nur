{
  lib,
  appimageTools,
  sources,
  ...
}:
let
  inherit (sources.duckstation) pname version src;
  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 rec {
  inherit pname version src;

  extraPreBwrapCmds = "unset QT_PLUGIN_PATH";

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/usr/share/applications/org.duckstation.DuckStation.desktop \
      $out/share/applications/org.duckstation.DuckStation.desktop
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/org.duckstation.DuckStation.png \
      $out/share/icons/hicolor/512x512/apps/org.duckstation.DuckStation.png
    substituteInPlace $out/share/applications/org.duckstation.DuckStation.desktop \
      --replace-fail "TryExec=duckstation-qt" "TryExec=$out/bin/${pname}" \
      --replace-fail "Exec=duckstation-qt %f" "Exec=$out/bin/${pname} %f"
  '';

  meta = with lib; {
    homepage = "https://www.duckstation.org";
    description = "Fast PlayStation 1 emulator for x86-64/AArch32/AArch64/RV64";
    platforms = [ "x86_64-linux" ];
  };
}
