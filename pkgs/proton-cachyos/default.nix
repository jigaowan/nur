{
  lib,
  stdenv,
  xz,
  sources,
  variant ? "base",
  ...
}:
let
  sourceName = if variant == "base" then "proton-cachyos" else "proton-cachyos-${variant}";
  source = sources.${sourceName};
  folderName = sourceName;
  steamName = if variant == "base" then "Proton CachyOS" else "Proton CachyOS ${variant}";
  mkProton =
    settings:
    let
      settingsAreStrings = lib.all builtins.isString (builtins.attrValues settings);
      settingsFile =
        assert lib.assertMsg settingsAreStrings "proton-cachyos settings values must be strings";
        builtins.toFile "proton-cachyos-user-settings.py" ''
          user_settings = ${builtins.toJSON settings}
        '';
    in
    stdenv.mkDerivation (
      {
        pname = folderName;
        version = lib.removePrefix "cachyos-" source.version;

        inherit (source) src;

        nativeBuildInputs = [ xz ];

        outputs = [
          "out"
          "steamcompattool"
        ];

        # Upstream release archives contain dead symlinks.
        dontCheckForBrokenSymlinks = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$steamcompattool"
          cp -r ./* "$steamcompattool/"

          sed -i -r 's|"display_name".*|"display_name" "${steamName}"|' \
            "$steamcompattool/compatibilitytool.vdf"
          sed -i -r 's|"proton-cachyos-[^"]*"(\s*// Internal name)|"${steamName}"\1|' \
            "$steamcompattool/compatibilitytool.vdf"

          mkdir -p "$out/share/steam/compatibilitytools.d/${folderName}"
          ln -s "$steamcompattool"/* "$out/share/steam/compatibilitytools.d/${folderName}/"

          runHook postInstall
        '';

        passthru = {
          inherit settings;
          withSettings = extraSettings: mkProton (settings // extraSettings);
        };

        meta = {
          description = steamName;
          homepage = "https://github.com/CachyOS/proton-cachyos";
          license = lib.licenses.bsd3;
          platforms = [ "x86_64-linux" ];
        };
      }
      // lib.optionalAttrs (settings != { }) {
        preInstall = ''
          mkdir -p "$steamcompattool"
          install -m 644 ${settingsFile} "$steamcompattool/user_settings.py"
        '';
      }
    );
in
mkProton { }
