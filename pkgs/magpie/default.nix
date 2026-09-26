{
  lib,
  stdenvNoCC,
  _7zz,
  sources,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "magpie";
  inherit (sources.magpie) version src;

  strictDeps = true;

  # magpie-darwin-arm64.dmg is APFS. undmg only extracts HFS.
  nativeBuildInputs = [ _7zz ];

  sourceRoot = "magpie.app";

  dontBuild = true;
  # Keep the Developer ID signature and stapled notarization ticket.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications/magpie.app
    cp -R . $out/Applications/magpie.app

    runHook postInstall
  '';

  meta = with lib; {
    description = "Menu bar app for choosing models across coding agents";
    homepage = "https://usemagpie.ai";
    downloadPage = "https://github.com/yetone/magpie-releases/releases";
    changelog = "https://github.com/yetone/magpie-releases/releases/tag/v${finalAttrs.version}";
    license = licenses.unfree;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
})
