{
  lib,
  buildGoModule,
  sources,
  ...
}:
let
  source = sources.simslim;
  version = lib.removePrefix "v" source.version;
in
buildGoModule {
  pname = "simslim";
  inherit version;
  inherit (source) src;

  vendorHash = "sha256-y6Nbszl+bmjxRII6pryzv31mZN2BpSTuZYmrEVKxqu4=";

  subPackages = [ "cmd/simslim" ];

  ldflags = [ "-X main.version=${version}" ];

  meta = with lib; {
    homepage = "https://github.com/MobAI-App/simslim";
    description = "Run more iOS simulators by disabling unneeded background daemons";
    license = licenses.mit;
    mainProgram = "simslim";
    platforms = platforms.darwin;
  };
}
