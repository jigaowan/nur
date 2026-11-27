{
  lib,
  pkgs,
  cfg,
}:

let
  toml = pkgs.formats.toml { };
  effectiveYtdlp =
    if cfg.jsRuntimePackage != null && cfg.ytdlpPackage ? override then
      cfg.ytdlpPackage.override { jsRuntime = cfg.jsRuntimePackage; }
    else
      cfg.ytdlpPackage;
  toolPython =
    let
      python =
        if (effectiveYtdlp.pythonModule or false) != false then
          effectiveYtdlp.pythonModule
        else
          effectiveYtdlp.python or pkgs.python3;
    in
    python.withPackages (ps: [ (ps.toPythonModule effectiveYtdlp) ]);
  effectiveYtdlpPython =
    if cfg.ytdlpPython != null then
      cfg.ytdlpPython
    else
      "${toolPython}/bin/python3";
in
toml.generate "pod-hub-config.toml" (
  lib.recursiveUpdate {
    paths = {
      state_dir = cfg.stateDir;
      output_dir = cfg.outputDir;
    };
    web = {
      listen_host = cfg.listenAddress;
      listen_port = cfg.port;
      base_url = cfg.baseUrl;
    };
    toolchain = {
      ytdlp_python = effectiveYtdlpPython;
      ffmpeg_path = "${cfg.ffmpegPackage}/bin/ffmpeg";
      ffprobe_path = "${cfg.ffmpegPackage}/bin/ffprobe";
      js_runtime = if cfg.jsRuntimePackage == null then "" else lib.getExe cfg.jsRuntimePackage;
    };
  } cfg.settings
)
