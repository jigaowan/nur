{
  lib,
  buildGoModule,
  sources,
  makeWrapper,
  hyprland,
  grim,
  slurp,
  hyprpicker,
  libnotify,
  ...
}:

let
  source = sources.scanocr-client;
  version = lib.removePrefix "client/v" source.version;
in
buildGoModule {
  pname = "scanocr-client";
  inherit version;
  inherit (source) src;

  modRoot = "client";
  vendorHash = "sha256-pbA/AlBz3cQYRTMnQ/qBPcinYOKokrBLNhkbRTq54gE=";

  subPackages = [ "." ];

  env.CGO_ENABLED = "0";

  ldflags = [ "-X main.clientVersion=${version}" ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    mv $out/bin/client $out/bin/scanocr-client
    wrapProgram $out/bin/scanocr-client \
      --prefix PATH : ${
        lib.makeBinPath [
          hyprland
          grim
          slurp
          hyprpicker
          libnotify
        ]
      }
  '';

  meta = with lib; {
    homepage = "https://github.com/jigaowan/scanocr";
    description = "Linux Hyprland screenshot client for ScanOCR";
    mainProgram = "scanocr-client";
    platforms = platforms.linux;
  };
}
