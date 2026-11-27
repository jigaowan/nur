{
  lib,
  python3,
  python3Packages,
  makeWrapper,
  ffmpeg,
  deno,
  yt-dlp,
  sources,
  ...
}:

let
  source = sources.pod-hub;
  ytdlpPython = python3.withPackages (ps: [ (ps.toPythonModule yt-dlp) ]);
in
python3Packages.buildPythonApplication {
  pname = "pod-hub";
  version = lib.removePrefix "v" source.version;
  pyproject = true;
  inherit (source) src;

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    fastapi
    starlette
    uvicorn
    jinja2
    python-multipart
    pydantic
    httpx
    socksio
    pathvalidate
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  nativeCheckInputs = (with python3Packages; [
    pytestCheckHook
    pytest-asyncio
  ]) ++ [
    ffmpeg
  ];

  pythonImportsCheck = [
    "podhub.cli"
    "podhub.main"
  ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      ffmpeg
      deno
    ])
    "--set-default"
    "PODHUB_DEFAULT_YTDLP_PYTHON"
    "${ytdlpPython}/bin/python3"
  ];

  meta = with lib; {
    homepage = "https://github.com/jigaowan/pod-hub";
    description = "Self-hosted YouTube-to-podcast service for NixOS";
    mainProgram = "pod-hub";
    platforms = platforms.unix;
  };
}
