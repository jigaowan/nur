{
  lib,
  stdenvNoCC,
  sources,
}:
let
  sourcesBySystem = {
    x86_64-linux = sources.magpie-cli-x86_64-linux;
    aarch64-linux = sources.magpie-cli-aarch64-linux;
    x86_64-darwin = sources.magpie-cli-x86_64-darwin;
    aarch64-darwin = sources.magpie-cli-aarch64-darwin;
  };
  source =
    sourcesBySystem.${stdenvNoCC.hostPlatform.system}
      or (throw "magpie-cli is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "magpie-cli";
  inherit (source) version src;

  strictDeps = true;

  dontUnpack = true;
  dontBuild = true;
  # Darwin builds are ad-hoc signed. Linux builds are already stripped.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/magpie

    runHook postInstall
  '';

  meta = with lib; {
    description = "Terminal client for choosing models across coding agents";
    homepage = "https://usemagpie.ai";
    downloadPage = "https://github.com/yetone/magpie-releases/releases";
    changelog = "https://github.com/yetone/magpie-releases/releases/tag/v${source.version}";
    license = licenses.unfree;
    mainProgram = "magpie";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
