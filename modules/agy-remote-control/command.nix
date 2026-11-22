{ lib, cfg }:
# Use the foreground daemon that `agy remote-control start` would register.
[ (lib.getExe' cfg.package "agy") ]
++ lib.optional (cfg.instanceName != null) "--remote-control-name=${cfg.instanceName}"
++ [
  "remote-control"
  "serve"
]
