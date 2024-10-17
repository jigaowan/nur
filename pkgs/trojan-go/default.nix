{ lib, buildGoModule, fetchFromGitHub, ... }:
buildGoModule rec {
  pname = "trojan-go";
  version = "0.10.6";
  src = fetchFromGitHub {
    owner = "p4gefau1t";
    repo = "trojan-go";
    rev = "v${version}";
    hash = "sha256-ZzIEKyLhHwYEWBfi6fHlCbkEImetEaRewbsHQEduB5Y=";
  };
  tags = "full";
  vendorHash = "sha256-c6H/8/dmCWasFKVR15U/kty4AzQAqmiL/VLKrPtH+s4=";
  doCheck = false;
  meta = with lib; {
    homepage = "https://p4gefau1t.github.io/trojan-go/";
    platforms = platforms.all;
  };
}
