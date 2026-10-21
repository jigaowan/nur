{
  caddy,
  go,
  lib,
}:

let
  # xcaddy writes the toolchain into go.mod (`go 1.26.x`). A Go patch
  # update changes this fixed-output source even when Caddy and the
  # plugins are unchanged.
  vendorHashes = {
    "1.26.8" = "sha256-rBv92HFAdmY35sxkkRf4PWbRdPQLSbO/KhK1Q3goOGA=";
    "1.26.9" = "sha256-WbcNLNtX/vK1JOrjABk+SKaCTmES1LaaSJxXH5ss5sU=";
  };
in
(caddy.withPlugins {
  plugins = [
    "github.com/caddy-dns/cloudflare@v0.2.4"
    "github.com/mholt/caddy-dynamicdns@v0.0.0-20260805195708-67d107a42c02"
  ];
  hash = vendorHashes.${go.version} or lib.fakeHash;
}).overrideAttrs
  (previous: {
    meta = (previous.meta or { }) // {
      description = "Caddy with the Cloudflare DNS and dynamic DNS plugins";
      broken = caddy.version != "2.11.7" || !lib.hasAttr go.version vendorHashes;
    };
  })
