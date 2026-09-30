{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
  wrapGAppsHook3,
  _7zz,
  gtk3,
  gdk-pixbuf,
  glib,
  xorg,
  webkitgtk_4_1,
  libsoup_3,
  sources,
}:
let
  system = stdenvNoCC.hostPlatform.system;
  isLinux = stdenvNoCC.hostPlatform.isLinux;
  sourcesBySystem = {
    x86_64-linux = sources.magpie-x86_64-linux;
    aarch64-linux = sources.magpie-aarch64-linux;
    aarch64-darwin = sources.magpie;
  };
  source = sourcesBySystem.${system} or (throw "magpie is not supported on ${system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "magpie";
  inherit (source) version src;

  strictDeps = true;

  # The macOS DMG uses APFS, which undmg cannot extract.
  nativeBuildInputs =
    if isLinux then
      [
        autoPatchelfHook
        wrapGAppsHook3
      ]
    else
      [ _7zz ];
  buildInputs = lib.optionals isLinux [
    gtk3
    gdk-pixbuf
    glib
    xorg.libX11
    webkitgtk_4_1
    libsoup_3
  ];

  dontUnpack = isLinux;
  sourceRoot = lib.optionalString (!isLinux) "magpie.app";

  dontBuild = true;
  # Preserve the Developer ID signature and notarization ticket on macOS.
  dontFixup = !isLinux;
  dontStrip = isLinux;

  installPhase =
    if isLinux then
      ''
        runHook preInstall

        # magpie-cli also installs $out/bin/magpie.
        install -Dm755 $src $out/bin/magpie-gui
        install -Dm644 /dev/stdin $out/share/applications/magpie.desktop <<'EOF'
        [Desktop Entry]
        Type=Application
        Name=Magpie
        Exec=magpie-gui
        Terminal=false
        Categories=Utility;
        EOF

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -p $out/Applications/magpie.app
        cp -R . $out/Applications/magpie.app

        runHook postInstall
      '';

  meta =
    (with lib; {
      description = "GUI app for choosing models across coding agents";
      homepage = "https://usemagpie.ai";
      downloadPage = "https://github.com/yetone/magpie-releases/releases";
      changelog = "https://github.com/yetone/magpie-releases/releases/tag/v${finalAttrs.version}";
      license = licenses.unfree;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    })
    // lib.optionalAttrs isLinux {
      mainProgram = "magpie-gui";
    };
})
