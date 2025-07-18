{ lib, buildGoModule, fetchFromGitHub, ... }:
buildGoModule rec {
  pname = "anytls-go";
  version = "0.0.8";
  src = fetchFromGitHub {
    owner = "anytls";
    repo = "anytls-go";
    rev = "v${version}";
    hash = "sha256-IxC7IqOxqMIZ+iv2N013ZiPw2JJFyX7KlsKm74gYr7w=";
  };
  vendorHash = "sha256-6dj/Iw4XRd0EHDSj0szyZ8/8uXaJ6VpTkDirBq6wrW0=";
  meta = with lib; {
    homepage = "https://github.com/anytls/anytls-go";
    platforms = platforms.all;
  };
}
