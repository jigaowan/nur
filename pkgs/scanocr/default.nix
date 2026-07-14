{
  lib,
  stdenvNoCC,
  sources,
  ...
}:
stdenvNoCC.mkDerivation {
  inherit (sources.scanocr) pname version src;

  strictDeps = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/scanocr-server $out/bin/scanocr-server
    install -Dm755 libexec/scanocr-native-helper $out/libexec/scanocr-native-helper

    runHook postInstall
  '';

  # Both Mach-O executables are ad-hoc signed in the release archive.
  dontStrip = true;

  meta = with lib; {
    homepage = "https://github.com/jigaowan/scanocr";
    description = "Personal macOS screenshot OCR and translation server";
    mainProgram = "scanocr-server";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
