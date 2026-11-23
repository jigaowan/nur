{
  autoPatchelfHook,
  lib,
  stdenv,
  stdenvNoCC,
  sources,
}:
let
  sourcesBySystem = {
    aarch64-darwin = sources.codex-bin-aarch64-darwin;
    aarch64-linux = sources.codex-bin-aarch64-linux;
    x86_64-darwin = sources.codex-bin-x86_64-darwin;
    x86_64-linux = sources.codex-bin-x86_64-linux;
  };
  inherit (stdenvNoCC.hostPlatform) system isLinux;
  source = sourcesBySystem.${system} or (throw "codex-bin is not supported on ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "codex-bin";
  inherit (source) version src;

  strictDeps = true;
  # Some Linux helpers are glibc-linked even though the CLI uses the musl target.
  nativeBuildInputs = lib.optional isLinux autoPatchelfHook;
  buildInputs = lib.optional isLinux (lib.getLib stdenv.cc.cc);
  preFixup = lib.optionalString isLinux ''
    addAutoPatchelfSearchPath "$out/codex-resources/voice/lib"
  '';
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Codex locates its manifest and bundled helpers relative to its executable.
    mkdir -p "$out"
    cp -R bin codex-package.json codex-path codex-resources "$out/"

    runHook postInstall
  '';

  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR/codex-check-home"
    export CODEX_HOME="$HOME/.codex"
    mkdir -p "$CODEX_HOME"
    test "$("$out/bin/codex" --version)" = "codex-cli $version"
    test -x "$out/bin/codex-code-mode-host"
    test -x "$out/codex-path/rg"
    test -f "$out/codex-package.json"

    runHook postInstallCheck
  '';

  meta = {
    description = "OpenAI Codex CLI, packaged from official releases";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${source.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "codex";
    platforms = builtins.attrNames sourcesBySystem;
  };
}
