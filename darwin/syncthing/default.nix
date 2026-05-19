{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  cfg = config.services.syncthing;
  opt = options.services.syncthing;

  defaultUser = "_syncthing";
  defaultGroup = defaultUser;

  settingsFormat = pkgs.formats.json { };
  cleanedConfig = lib.converge (lib.filterAttrsRecursive (_: v: v != null && v != { })) cfg.settings;

  isUnixGui = lib.strings.hasPrefix "unix://" cfg.guiAddress;

  curlAddressArgs =
    path:
    if isUnixGui then
      "--unix-socket ${lib.strings.removePrefix "unix://" cfg.guiAddress} http://.${path}"
    else
      "${cfg.guiAddress}${path}";

  devices = lib.mapAttrsToList (
    _: device:
    device
    // {
      deviceID = device.id;
    }
  ) cfg.settings.devices;

  anyAutoAccept = builtins.any (device: device.autoAcceptFolders) devices;

  folders = lib.mapAttrsToList (
    folderName: folder:
    folder
    //
      lib.throwIf (folder ? rescanInterval || folder ? watch || folder ? watchDelay)
        ''
          The options services.syncthing.settings.folders.<name>.{rescanInterval,watch,watchDelay}
          were removed. Please use, respectively, {rescanIntervalS,fsWatcherEnabled,fsWatcherDelayS} instead.
        ''
        {
          devices = map (
            device:
            if builtins.isString device then
              { deviceId = cfg.settings.devices.${device}.id; }
            else if builtins.isAttrs device && device ? name && device.name != null then
              { deviceId = cfg.settings.devices.${device.name}.id; } // device
            else if builtins.isAttrs device then
              device
            else
              throw "Invalid type for devices in folder '${folderName}'; expected string or attrset."
          ) folder.devices;
        }
  ) (lib.filterAttrs (_: folder: folder.enable) cfg.settings.folders);

  jq = "${pkgs.jq}/bin/jq";
  grep = lib.getExe pkgs.gnugrep;

  updateConfig = pkgs.writers.writeBash "merge-syncthing-config" (
    ''
      set -efu

      umask 0077

      curl() {
          while
              ! ${pkgs.libxml2}/bin/xmllint \
                  --xpath 'string(configuration/gui/apikey)' \
                  ${cfg.configDir}/config.xml \
                  >"$RUNTIME_DIRECTORY/api_key"
          do sleep 1; done
          (printf "X-API-Key: "; cat "$RUNTIME_DIRECTORY/api_key") >"$RUNTIME_DIRECTORY/headers"
          ${pkgs.curl}/bin/curl -sSLk -H "@$RUNTIME_DIRECTORY/headers" \
              --retry 1000 --retry-delay 1 --retry-all-errors \
              "$@"
      }

      while true
      do
        content_type="$(curl \
          -o /dev/null \
          -w '%header{Content-Type}' \
          ${curlAddressArgs "/rest/noauth/health"}
        )"

        if printf %s "$content_type" | ${lib.escapeShellArg grep} -qiP '^text/plain($|([ \t]*;.*))'
        then
          echo 'Waiting for Syncthing to finish its database migration...'
          sleep 30
        elif printf %s "$content_type" | ${lib.escapeShellArg grep} -qiP '^application/json($|([ \t]*;.*))'
        then
          echo 'Syncthing is not doing a database migration.'
          break
        else
          printf 'ERROR: Syncthing responded with an unexpected Content-Type: %s\n' "$content_type"
          exit 76
        fi
      done
    ''
    + (lib.pipe
      {
        devs = {
          new_conf_IDs = map (v: v.id) devices;
          GET_IdAttrName = "deviceID";
          override = cfg.overrideDevices;
          conf = devices;
          baseAddress = curlAddressArgs "/rest/config/devices";
        };
        dirs = {
          new_conf_IDs = map (v: v.id) folders;
          GET_IdAttrName = "id";
          override = cfg.overrideFolders;
          conf = folders;
          baseAddress = curlAddressArgs "/rest/config/folders";
          ignoreAddress = curlAddressArgs "/rest/db/ignores";
        };
      }
      [
        (lib.mapAttrs (
          confType: s:
          lib.pipe s.conf [
            (map (
              newCfg:
              let
                jsonPreSecretsFile = pkgs.writeTextFile {
                  name = "${confType}-${newCfg.id}-conf-pre-secrets.json";
                  text = builtins.toJSON (builtins.removeAttrs newCfg [ "ignorePatterns" ]);
                };
                injectSecretsJqCmd =
                  {
                    devs = "${jq} .";
                    dirs =
                      let
                        devicesWithSecrets = lib.pipe newCfg.devices [
                          (lib.filter (
                            device:
                            (builtins.isAttrs device)
                            && device ? encryptionPasswordFile
                            && device.encryptionPasswordFile != null
                          ))
                          (map (device: {
                            deviceId = device.deviceId;
                            variableName = "secret_${builtins.hashString "sha256" device.encryptionPasswordFile}";
                            secretPath = device.encryptionPasswordFile;
                          }))
                        ];
                        jqUpdates = map (device: ''
                          .devices[] |= (
                            if .deviceId == "${device.deviceId}" then
                              del(.encryptionPasswordFile) |
                              .encryptionPassword = ''$${device.variableName}
                            else
                              .
                            end
                          )
                        '') devicesWithSecrets;
                        jqRawFiles = map (
                          device: "--rawfile ${device.variableName} ${lib.escapeShellArg device.secretPath}"
                        ) devicesWithSecrets;
                      in
                      "${jq} ${lib.concatStringsSep " " jqRawFiles} ${
                        lib.escapeShellArg (lib.concatStringsSep "|" ([ "." ] ++ jqUpdates))
                      }";
                  }
                  .${confType};
              in
              ''
                ${injectSecretsJqCmd} ${jsonPreSecretsFile} | curl --json @- -X POST ${s.baseAddress}
              ''
              + lib.optionalString ((confType == "dirs") && (newCfg.ignorePatterns != null)) ''
                curl -d '{"ignore": ${builtins.toJSON newCfg.ignorePatterns}}' -X POST ${s.ignoreAddress}?folder=${lib.strings.escapeURL newCfg.id}
              ''
            ))
            (lib.concatStringsSep "\n")
          ]
          + lib.optionalString s.override ''
            stale_${confType}_ids="$(curl -X GET ${s.baseAddress} | ${jq} \
              --argjson new_ids ${lib.escapeShellArg (builtins.toJSON s.new_conf_IDs)} \
              --raw-output \
              '[.[].${s.GET_IdAttrName}] - $new_ids | .[]|@uri'
            )"
            for id in ''${stale_${confType}_ids}; do
              >&2 echo "Deleting stale ${confType} entry: $id"
              curl -X DELETE ${s.baseAddress}/$id
            done
          ''
        ))
        builtins.attrValues
        (lib.concatStringsSep "\n")
      ]
    )
    + (lib.pipe cleanedConfig [
      builtins.attrNames
      (lib.subtractLists [
        "folders"
        "devices"
        "guiPasswordFile"
      ])
      (map (subOption: ''
        curl -X PUT -d ${
          lib.escapeShellArg (builtins.toJSON cleanedConfig.${subOption})
        } ${curlAddressArgs "/rest/config/${subOption}"}
      ''))
      (lib.concatStringsSep "\n")
    ])
    + lib.optionalString (cfg.guiPasswordFile != null) ''
      ${pkgs.mkpasswd}/bin/mkpasswd -m bcrypt --stdin <"${cfg.guiPasswordFile}" | tr -d "\n" > "$RUNTIME_DIRECTORY/password_bcrypt"
      curl -X PATCH --variable "pw_bcrypt@$RUNTIME_DIRECTORY/password_bcrypt" --expand-json '{ "password": "{{pw_bcrypt}}" }' ${curlAddressArgs "/rest/config/gui"}
    ''
    + ''
      if curl ${curlAddressArgs "/rest/config/restart-required"} |
         ${jq} -e .requiresRestart > /dev/null; then
          curl -X POST ${curlAddressArgs "/rest/system/restart"}
      fi
    ''
  );

  runSyncthing = pkgs.writers.writeBash "run-syncthing" ''
    set -efu

    runtime_dir="$(${pkgs.coreutils}/bin/mktemp -d "''${TMPDIR:-/tmp}/syncthing-init.XXXXXX")"
    export RUNTIME_DIRECTORY="$runtime_dir"

    syncthing_pid=
    cleanup() {
      status=$?
      if [ -n "$syncthing_pid" ] && kill -0 "$syncthing_pid" >/dev/null 2>&1; then
        kill "$syncthing_pid" >/dev/null 2>&1 || true
        wait "$syncthing_pid" >/dev/null 2>&1 || true
      fi
      ${pkgs.coreutils}/bin/rm -rf "$runtime_dir"
      exit "$status"
    }
    trap cleanup INT TERM EXIT

    ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg (toString cfg.dataDir)}
    ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg (toString cfg.configDir)}
    ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg (toString cfg.databaseDir)}

    ${lib.optionalString (cfg.cert != null) ''
      ${pkgs.coreutils}/bin/install -Dm644 ${lib.escapeShellArg (toString cfg.cert)} ${lib.escapeShellArg "${toString cfg.configDir}/cert.pem"}
    ''}
    ${lib.optionalString (cfg.key != null) ''
      ${pkgs.coreutils}/bin/install -Dm600 ${lib.escapeShellArg (toString cfg.key)} ${lib.escapeShellArg "${toString cfg.configDir}/key.pem"}
    ''}

    ${lib.getExe cfg.package} ${
      lib.escapeShellArgs (
        [
          "serve"
          "--no-browser"
          "--gui-address=${cfg.guiAddress}"
          "--config=${toString cfg.configDir}"
          "--data=${toString cfg.databaseDir}"
        ]
        ++ cfg.extraFlags
      )
    } &
    syncthing_pid=$!

    ${lib.optionalString (cleanedConfig != { } || cfg.guiPasswordFile != null) ''
      for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
        if [ -f ${lib.escapeShellArg "${toString cfg.configDir}/config.xml"} ]; then
          break
        fi
        if ! kill -0 "$syncthing_pid" >/dev/null 2>&1; then
          wait "$syncthing_pid"
          exit "$?"
        fi
        sleep 1
      done
      if [ ! -f ${lib.escapeShellArg "${toString cfg.configDir}/config.xml"} ]; then
        echo 'Timed out waiting for Syncthing to create config.xml.' >&2
        exit 1
      fi
      ${updateConfig}
    ''}

    wait "$syncthing_pid"
  '';
in
{
  options.services.syncthing = {
    enable = lib.mkEnableOption "Syncthing, a self-hosted open-source alternative to Dropbox and Bittorrent Sync";

    cert = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the `cert.pem` file, which will be copied into Syncthing's
        [configDir](#opt-services.syncthing.configDir).
      '';
    };

    key = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the `key.pem` file, which will be copied into Syncthing's
        [configDir](#opt-services.syncthing.configDir).
      '';
    };

    guiPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to file containing the plaintext password for Syncthing's GUI.
      '';
    };

    overrideDevices = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to delete devices which are not configured through
        [settings.devices](#opt-services.syncthing.settings.devices).
      '';
    };

    overrideFolders = lib.mkOption {
      type = lib.types.bool;
      default = !anyAutoAccept;
      defaultText = lib.literalMD ''
        `true` unless any device has the
        [autoAcceptFolders](#opt-services.syncthing.settings.devices._name_.autoAcceptFolders)
        option set to `true`.
      '';
      description = ''
        Whether to delete folders which are not configured through
        [settings.folders](#opt-services.syncthing.settings.folders).
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
        options = {
          options = lib.mkOption {
            default = { };
            description = ''
              The options element contains all other global configuration options.
            '';
            type = lib.types.submodule {
              freeformType = settingsFormat.type;
              options = {
                localAnnounceEnabled = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether to send and use local LAN announcements.";
                };

                localAnnouncePort = lib.mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "The port on which to listen and send IPv4 broadcast announcements.";
                };

                relaysEnabled = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether relays will be connected to and potentially used.";
                };

                urAccepted = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "Whether the user has accepted anonymous usage reporting.";
                };

                limitBandwidthInLan = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether to apply bandwidth limits to devices in the same broadcast domain.";
                };

                maxFolderConcurrency = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "How many folders may concurrently be in I/O-intensive operations.";
                };
              };
            };
          };

          devices = lib.mkOption {
            default = { };
            description = ''
              Peers/devices which Syncthing should communicate with.
            '';
            example = {
              bigbox = {
                id = "7CFNTQM-IMTJBHJ-3UWRDIU-ZGQJFR6-VCXZ3NB-XUH3KZO-N52ITXR-LAIYUAU";
                addresses = [ "tcp://192.168.0.10:51820" ];
              };
            };
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  freeformType = settingsFormat.type;
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                      description = "The name of the device.";
                    };

                    id = lib.mkOption {
                      type = lib.types.str;
                      description = "The device ID.";
                    };

                    autoAcceptFolders = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Automatically create or share folders this device advertises.";
                    };
                  };
                }
              )
            );
          };

          folders = lib.mkOption {
            default = { };
            description = ''
              Folders which should be shared by Syncthing.
            '';
            example = lib.literalExpression ''
              {
                "/Users/alice/sync" = {
                  id = "syncme";
                  devices = [ "bigbox" ];
                };
              }
            '';
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  freeformType = settingsFormat.type;
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Whether to share this folder.";
                    };

                    path = lib.mkOption {
                      type = lib.types.str // {
                        check = x: lib.types.str.check x && (lib.substring 0 1 x == "/" || lib.substring 0 2 x == "~/");
                        description = lib.types.str.description + " starting with / or ~/";
                      };
                      default = name;
                      description = "The path to the folder which should be shared.";
                    };

                    id = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                      description = "The ID of the folder. Must be the same on all devices.";
                    };

                    label = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                      description = "The label of the folder.";
                    };

                    type = lib.mkOption {
                      type = lib.types.enum [
                        "sendreceive"
                        "sendonly"
                        "receiveonly"
                        "receiveencrypted"
                      ];
                      default = "sendreceive";
                      description = "Controls how the folder is handled by Syncthing.";
                    };

                    devices = lib.mkOption {
                      type = lib.types.listOf (
                        lib.types.oneOf [
                          lib.types.str
                          (lib.types.submodule {
                            freeformType = settingsFormat.type;
                            options = {
                              name = lib.mkOption {
                                type = lib.types.nullOr lib.types.str;
                                default = null;
                                description = "The name of a device defined in settings.devices.";
                              };

                              encryptionPasswordFile = lib.mkOption {
                                type = lib.types.nullOr lib.types.str;
                                default = null;
                                description = "Path to a file containing the encryption password.";
                              };
                            };
                          })
                        ]
                      );
                      default = [ ];
                      description = "The devices this folder should be shared with.";
                    };

                    versioning = lib.mkOption {
                      default = null;
                      description = "How to keep changed or deleted files with Syncthing.";
                      type =
                        with lib.types;
                        nullOr (submodule {
                          freeformType = settingsFormat.type;
                          options.type = lib.mkOption {
                            type = enum [
                              "external"
                              "simple"
                              "staggered"
                              "trashcan"
                            ];
                            description = "The type of versioning.";
                          };
                        });
                    };

                    copyOwnershipFromParent = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Try to copy file/folder ownership from the parent directory.";
                    };

                    ignorePatterns = lib.mkOption {
                      type = lib.types.nullOr (lib.types.listOf lib.types.str);
                      default = null;
                      description = "Syncthing ignore patterns for this folder.";
                      example = [
                        "// This is a comment"
                        "*.part // Firefox downloads and other things"
                        "*.crdownload // Chromium and Chrome downloads"
                      ];
                    };
                  };
                }
              )
            );
          };
        };
      };
      default = { };
      description = ''
        Extra configuration options for Syncthing, using the JSON REST API shape.
      '';
      example = {
        options.localAnnounceEnabled = false;
        gui.theme = "black";
      };
    };

    guiAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8384";
      apply = x: if lib.strings.hasPrefix "/" x then "unix://${x}" else x;
      description = "The address to serve the web interface at.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = defaultUser;
      example = "alice";
      description = "The user to run Syncthing as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = defaultGroup;
      example = "staff";
      description = "The group to run Syncthing under.";
    };

    all_proxy = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "socks5://address.com:1234";
      description = "Overwrite the all_proxy environment variable for the Syncthing process.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/syncthing";
      example = "/Users/alice";
      description = "The path where synchronised directories will exist.";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      description = "The path where the settings and keys will exist.";
      default = cfg.dataDir + "/.config/syncthing";
      defaultText = lib.literalExpression "config.${opt.dataDir} + \"/.config/syncthing\"";
    };

    databaseDir = lib.mkOption {
      type = lib.types.path;
      description = "The directory containing the database and logs.";
      default = cfg.configDir;
      defaultText = lib.literalExpression "config.${opt.configDir}";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--reset-deltas" ];
      description = "Extra flags passed to the syncthing command.";
    };

    package = lib.mkPackageOption pkgs "syncthing" { };
  };

  imports = [
    (lib.mkRemovedOptionModule [ "services" "syncthing" "useInotify" ] ''
      This option was removed because Syncthing now has fswatcher support built in.
    '')
    (lib.mkRenamedOptionModule
      [ "services" "syncthing" "extraOptions" ]
      [ "services" "syncthing" "settings" ]
    )
    (lib.mkRenamedOptionModule
      [ "services" "syncthing" "folders" ]
      [ "services" "syncthing" "settings" "folders" ]
    )
    (lib.mkRenamedOptionModule
      [ "services" "syncthing" "devices" ]
      [ "services" "syncthing" "settings" "devices" ]
    )
    (lib.mkRenamedOptionModule
      [ "services" "syncthing" "options" ]
      [ "services" "syncthing" "settings" "options" ]
    )
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.overrideFolders && anyAutoAccept);
        message = ''
          services.syncthing.overrideFolders will delete auto-accepted folders
          from the configuration, creating path conflicts.
        '';
      }
      {
        assertion = (lib.hasAttrByPath [ "gui" "password" ] cfg.settings) -> cfg.guiPasswordFile == null;
        message = ''
          Please use only one of services.syncthing.settings.gui.password or services.syncthing.guiPasswordFile.
        '';
      }
      {
        assertion = (cfg.user == defaultUser) == (cfg.group == defaultGroup);
        message = ''
          services.syncthing.user and services.syncthing.group must both use the default _syncthing identity,
          or both be set to an existing custom macOS identity.
        '';
      }
    ];

    ids.uids.${defaultUser} = lib.mkDefault 536;
    ids.gids.${defaultGroup} = lib.mkDefault 536;

    users.users = lib.mkIf (cfg.user == defaultUser) {
      ${defaultUser} = {
        uid = config.ids.uids.${defaultUser};
        gid = config.ids.gids.${defaultGroup};
        home = cfg.dataDir;
        createHome = true;
        shell = "/usr/bin/false";
        description = "System user for Syncthing";
      };
    };

    users.groups = lib.mkIf (cfg.group == defaultGroup) {
      ${defaultGroup} = {
        gid = config.ids.gids.${defaultGroup};
        description = "System group for Syncthing";
      };
    };

    users.knownUsers = lib.mkIf (cfg.user == defaultUser) [ defaultUser ];
    users.knownGroups = lib.mkIf (cfg.group == defaultGroup) [ defaultGroup ];

    environment.systemPackages = [ cfg.package ];

    launchd.daemons.syncthing = {
      command = runSyncthing;
      environment = {
        STNORESTART = "yes";
        STNOUPGRADE = "yes";
      }
      // lib.optionalAttrs (cfg.all_proxy != null) {
        all_proxy = cfg.all_proxy;
      };
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        UserName = cfg.user;
        GroupName = cfg.group;
      };
    };
  };
}
