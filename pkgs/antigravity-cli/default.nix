{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
  makeWrapper,
  sources,
}:
let
  sourcesBySystem = {
    aarch64-darwin = sources.antigravity-cli-aarch64-darwin;
    x86_64-darwin = sources.antigravity-cli-x86_64-darwin;
    aarch64-linux = sources.antigravity-cli-aarch64-linux;
    x86_64-linux = sources.antigravity-cli-x86_64-linux;
  };
  inherit (stdenvNoCC.hostPlatform) system isLinux;
  source = sourcesBySystem.${system} or (throw "antigravity-cli is not supported on ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit (source) version src;

  strictDeps = true;
  nativeBuildInputs = [ makeWrapper ] ++ lib.optional isLinux autoPatchelfHook;
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 antigravity "$out/bin/agy"
    wrapProgram "$out/bin/agy" --set AGY_CLI_DISABLE_AUTO_UPDATE true

    runHook postInstall
  '';

  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR/agy-check-home"
    mkdir -p "$HOME"
    test "$("$out/bin/agy" --version)" = "$version"
    "$out/bin/agy" remote-control start --help > /dev/null

    runHook postInstallCheck
  '';

  meta = {
    description = "Command-line interface for Google Antigravity";
    homepage = "https://antigravity.google/product/antigravity-cli";
    changelog = "https://github.com/google-antigravity/antigravity-cli/releases/tag/${source.version}";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "agy";
    platforms = builtins.attrNames sourcesBySystem;
  };
}
