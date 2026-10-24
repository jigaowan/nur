{
  lib,
  stdenv,
  buildNpmPackage,
  importNpmLock,
  nodejs_22,
  srcOnly,
  sources,
  autoPatchelfHook,
  cacert,
}:
let
  packageLock = lib.importJSON ./package-lock.json;
in
assert packageLock.version == sources.cloudflare-cf.version;
(buildNpmPackage.override { nodejs = nodejs_22; }) {
  pname = "cloudflare-cf";
  inherit (sources.cloudflare-cf) version src;

  npmDeps = importNpmLock {
    inherit packageLock;
    package = packageLock.packages."";
  };
  # Keep native-addon headers and node-gyp aligned with the runtime.
  npmConfigHook = importNpmLock.npmConfigHook.overrideAttrs {
    nodeSrc = srcOnly nodejs_22;
    nodeGyp = "${nodejs_22}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js";
  };

  # The npm release already contains the compiled CLI. Its development
  # dependencies include unpublished build tooling and are not needed at runtime.
  postPatch = ''
    ${lib.getExe nodejs_22} --input-type=commonjs -e '
      const fs = require("node:fs");
      const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
      delete pkg.devDependencies;
      fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
    '
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;
  npmInstallFlags = [ "--omit=dev" ];
  # workerd's install script executes its unpatched binary on Linux. The
  # platform package already supplies that binary; patch it during fixup.
  npmRebuildFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  dontStrip = true;
  makeWrapperArgs = [
    "--set-default NODE_EXTRA_CA_CERTS ${cacert}/etc/ssl/certs/ca-bundle.crt"
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export XDG_CONFIG_HOME="$TMPDIR/cf-config"
    export XDG_CACHE_HOME="$TMPDIR/cf-cache"
    export CF_SEND_TELEMETRY=false
    $out/bin/cf --version | grep -F "$version"
    $out/bin/cloudflare --help > /dev/null
    $out/lib/node_modules/cf/node_modules/workerd/bin/workerd --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Agent-oriented CLI for the entire Cloudflare API and Workers projects";
    homepage = "https://github.com/cloudflare/cf";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "cf";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
