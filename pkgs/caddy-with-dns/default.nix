{
  caddy,
  lib,
}:

# The fixed-output hash is for Caddy 2.11.7's vendored plugin source.
(caddy.withPlugins {
  plugins = [
    "github.com/caddy-dns/cloudflare@v0.2.4"
    "github.com/mholt/caddy-dynamicdns@v0.0.0-20260805195708-67d107a42c02"
  ];
  hash = "sha256-rBv92HFAdmY35sxkkRf4PWbRdPQLSbO/KhK1Q3goOGA=";
}).overrideAttrs
  (previous: {
    meta = (previous.meta or { }) // {
      description = "Caddy with the Cloudflare DNS and dynamic DNS plugins";
      broken = caddy.version != "2.11.7";
    };
  })
