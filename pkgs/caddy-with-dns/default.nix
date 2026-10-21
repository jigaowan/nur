{
  caddy,
  cacert,
  git,
  go,
  lib,
  stdenv,
  xcaddy,
}:

let
  plugins = [
    "github.com/caddy-dns/cloudflare@v0.2.4"
    "github.com/mholt/caddy-dynamicdns@v0.0.0-20260805195708-67d107a42c02"
  ];
  withArgs = lib.concatMapStrings (plugin: "--with ${plugin} ") (lib.sort lib.lessThan plugins);

  # xcaddy stamps the full Go patch version into go.mod. Normalize it to
  # the language minor so Go 1.26.8 and 1.26.9 share one fixed-output hash.
  src = stdenv.mkDerivation {
    pname = "caddy-src-with-plugins";
    inherit (caddy) version;

    nativeBuildInputs = [
      go
      xcaddy
      cacert
      git
    ];
    dontUnpack = true;

    env.GOTOOLCHAIN = "local";
    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
      "GOPROXY"
    ];

    buildPhase = ''
      export GOCACHE=$TMPDIR/go-cache
      export GOPATH="$TMPDIR/go"
      XCADDY_SKIP_BUILD=1 TMPDIR="$PWD" xcaddy build v${caddy.version} ${withArgs}
      (
        cd buildenv*
        go mod vendor
        go_minor="$(go env GOVERSION)"
        go_minor="''${go_minor#go}"
        go_minor="''${go_minor%.*}"
        sed -i -E "s/^go .*/go ''${go_minor}/" go.mod
        grep -q "^go ''${go_minor}$" go.mod
      )
    '';

    installPhase = ''
      mv buildenv* $out
    '';

    outputHashMode = "recursive";
    outputHash = "sha256-seuqGSYpFxOLZJ502qc9ae1NQTmj8T10ix753VDxXug=";
    outputHashAlgo = "sha256";
  };
in
# withPlugins only supplies the plugin version check. Its generated source
# embeds the Go patch version, so the hashed source is `src` above.
(caddy.withPlugins {
  inherit plugins;
  hash = lib.fakeHash;
}).overrideAttrs
  (previous: {
    inherit src;
    meta = (previous.meta or { }) // {
      description = "Caddy with the Cloudflare DNS and dynamic DNS plugins";
      broken = caddy.version != "2.11.7";
    };
  })
