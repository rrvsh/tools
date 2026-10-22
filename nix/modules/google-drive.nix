/*
  Runtime-authenticated Google Drive mounts.

  Each entry under `services.google-drive.accounts` creates an independent
  rclone remote and mount:

    services.google-drive.accounts.<name> = {
      email = "user@example.com";
      mountName = "example";
    };

  Derived paths:

    Mount:  ~/Drives/<mountName>
    Config: ~/.config/rclone/accounts/<name>.conf
    Cache:  ~/.cache/rclone/<name>
    State:  ~/.local/state/rclone/<name>

  OAuth credentials remain writable, host-local runtime state. They are not
  placed in the Nix store. Authentication uses rclone's built-in Google OAuth
  client. Set `services.google-drive.localBrowser = false` on headless hosts.

  macOS mounts through rclone's local NFS server. Linux mounts through FUSE.
  Reads stream from Google Drive. Writes use a bounded local VFS cache. An
  unmounted mount point is left non-writable to avoid accidental local writes.

  CLI:

    gdrive list
    gdrive auth <account>
    gdrive reauth <account>
    gdrive start <account>
    gdrive stop <account>
    gdrive status [account]
    gdrive logs <account>

  `auth` creates the named rclone remote and starts its mount. `status` without
  an account reports every configured account.
*/
{ config, ... }:
let
  osModule = {
    home-manager.sharedModules = [ config.flake.modules.homeManager.google-drive ];
  };
in
{
  config.flake.modules = {
    darwin.google-drive = osModule;
    nixos.google-drive =
      { primaryUser, ... }:
      {
        imports = [ osModule ];
        programs.fuse.enable = true;
        users.users.${primaryUser.name}.linger = true;
      };
    homeManager.google-drive =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.services.google-drive;
        configDirectory = "${config.xdg.configHome}/rclone/accounts";
        mountRoot = "${config.home.homeDirectory}/Drives";
        configuredAccounts = lib.mapAttrs (
          name: account:
          let
            configPath = "${configDirectory}/${name}.conf";
            mountPoint = "${mountRoot}/${account.mountName}";
            cacheDirectory = "${config.xdg.cacheHome}/rclone/${name}";
            stateDirectory = "${config.xdg.stateHome}/rclone/${name}";
            logPath = "${stateDirectory}/rclone.log";
            serviceName = "rclone-google-drive-${name}";
            mountCheck =
              if pkgs.stdenv.hostPlatform.isDarwin then
                ''/sbin/mount | ${lib.getExe pkgs.gnugrep} -Fq " on $mount_point "''
              else
                ''${lib.getExe' pkgs.util-linux "mountpoint"} -q "$mount_point"'';
            mountRunner = pkgs.writeShellApplication {
              name = serviceName;
              runtimeInputs = with pkgs; [
                coreutils
                findutils
                gnugrep
                rclone
              ];
              text = ''
                config_path=${lib.escapeShellArg configPath}
                mount_point=${lib.escapeShellArg mountPoint}
                cache_directory=${lib.escapeShellArg cacheDirectory}
                state_directory=${lib.escapeShellArg stateDirectory}
                log_path=${lib.escapeShellArg logPath}

                protect_mount_point() {
                  if ! ${mountCheck}; then
                    chmod 0500 "$mount_point"
                  fi
                }

                mkdir -p "$mount_point" "$cache_directory" "$state_directory"
                chmod 0700 "$cache_directory" "$state_directory"

                if ${mountCheck}; then
                  echo "$mount_point is already mounted" >&2
                  exit 0
                fi

                if [ ! -r "$config_path" ]; then
                  protect_mount_point
                  exit 0
                fi

                if ! rclone --config "$config_path" listremotes | grep -Fxq '${name}:'; then
                  echo "Remote ${name}: is missing from $config_path; run: gdrive auth ${name}" >&2
                  protect_mount_point
                  exit 0
                fi

                if find "$mount_point" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
                  echo "Refusing to mount over non-empty directory: $mount_point" >&2
                  protect_mount_point
                  exit 1
                fi

                chmod 0700 "$mount_point"
                mkdir -p "$cache_directory/nfs-handles"

                common_arguments=(
                  --config "$config_path"
                  --cache-dir "$cache_directory"
                  --vfs-cache-mode writes
                  --vfs-cache-max-size 2G
                  --vfs-cache-max-age 1h
                  --vfs-cache-poll-interval 1m
                  --vfs-write-back 5s
                  --buffer-size 16M
                  --dir-cache-time 72h
                  --poll-interval 1m
                  --umask 077
                  --log-file "$log_path"
                  --log-level NOTICE
                  --log-file-max-size 5M
                  --log-file-max-backups 2
                  --log-file-max-age 7d
                )

                ${lib.optionalString (!pkgs.stdenv.hostPlatform.isDarwin) ''export PATH="/run/wrappers/bin:$PATH"''}
                ${
                  if pkgs.stdenv.hostPlatform.isDarwin then
                    ''
                      rclone nfsmount \
                        --nfs-cache-type disk \
                        --nfs-cache-dir "$cache_directory/nfs-handles" \
                        "''${common_arguments[@]}" \
                        '${name}:' "$mount_point" &
                    ''
                  else
                    ''
                      rclone mount \
                        "''${common_arguments[@]}" \
                        '${name}:' "$mount_point" &
                    ''
                }
                child_pid=$!

                # shellcheck disable=SC2329 # Invoked indirectly by signal traps.
                terminate() {
                  trap - INT TERM EXIT
                  kill -TERM "$child_pid" 2>/dev/null || true
                  wait "$child_pid" 2>/dev/null || true
                  protect_mount_point
                  exit 0
                }

                trap terminate INT TERM
                trap protect_mount_point EXIT

                set +e
                wait "$child_pid"
                exit $?
              '';
            };
          in
          account
          // {
            inherit
              cacheDirectory
              configPath
              logPath
              mountCheck
              mountPoint
              mountRunner
              serviceName
              stateDirectory
              ;
          }
        ) cfg.accounts;
      in
      {
        options.services.google-drive = {
          accounts = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  email = lib.mkOption {
                    type = lib.types.str;
                    description = "Google account shown by the gdrive helper.";
                  };
                  mountName = lib.mkOption {
                    type = lib.types.str;
                    description = "Directory name created under ~/Drives.";
                  };
                };
              }
            );
            default = { };
            description = "Google Drive accounts available on this host.";
          };
          localBrowser = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether rclone can open a local browser for OAuth.";
          };
        };

        config = lib.mkIf (cfg.accounts != { }) {
          home = {
            packages = [
              (pkgs.writeShellApplication {
                name = "gdrive";
                runtimeInputs =
                  with pkgs;
                  [
                    coreutils
                    findutils
                    gnugrep
                    rclone
                  ]
                  ++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
                    systemd
                    util-linux
                  ];
                text = ''
                  action="''${1:-}"
                  account_name="''${2:-}"

                  if [ "$action" = list ]; then
                    ${lib.concatStringsSep "\n" (
                      lib.mapAttrsToList (name: account: "echo '${name} -> ${account.mountPoint}' ") configuredAccounts
                    )}
                    exit 0
                  fi

                  if [ "$action" = status ] && [ -z "$account_name" ]; then
                    ${lib.concatStringsSep "\n" (
                      map (name: ''"$0" status '${name}' '') (builtins.attrNames configuredAccounts)
                    )}
                    exit 0
                  fi

                  case "$account_name" in
                    ${lib.concatStringsSep "\n" (
                      lib.mapAttrsToList (name: account: ''
                        '${name}')
                          account_email=${lib.escapeShellArg account.email}
                          config_path=${lib.escapeShellArg account.configPath}
                          mount_point=${lib.escapeShellArg account.mountPoint}
                          cache_directory=${lib.escapeShellArg account.cacheDirectory}
                          log_path=${lib.escapeShellArg account.logPath}
                          ${lib.optionalString (
                            !pkgs.stdenv.hostPlatform.isDarwin
                          ) "service_name=${lib.escapeShellArg account.serviceName}"}
                          ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "launchd_label=${lib.escapeShellArg "org.nix-community.home.${account.serviceName}"}"}
                          ;;
                      '') configuredAccounts
                    )}
                    *)
                      echo "Unknown account: ''${account_name:-<missing>}" >&2
                      echo "Available accounts:" >&2
                      ${lib.concatStringsSep "\n" (
                        map (name: "echo '  ${name}' >&2 ") (builtins.attrNames configuredAccounts)
                      )}
                      exit 2
                      ;;
                  esac

                  remote_configured=false
                  if [ -r "$config_path" ] && rclone --config "$config_path" listremotes | grep -Fxq "$account_name:"; then
                    remote_configured=true
                  fi

                  mounted=false
                  if ${
                    if pkgs.stdenv.hostPlatform.isDarwin then
                      ''/sbin/mount | grep -Fq " on $mount_point "''
                    else
                      ''mountpoint -q "$mount_point"''
                  }; then
                    mounted=true
                  fi

                  start_service() {
                    if [ "$remote_configured" != true ]; then
                      echo "$account_name: is not configured; run: gdrive auth $account_name" >&2
                      exit 1
                    fi
                    ${
                      if pkgs.stdenv.hostPlatform.isDarwin then
                        ''
                          domain="gui/$(id -u)"
                          if ! /bin/launchctl print "$domain/$launchd_label" >/dev/null 2>&1; then
                            /bin/launchctl bootstrap "$domain" "${config.home.homeDirectory}/Library/LaunchAgents/$launchd_label.plist"
                          fi
                          /bin/launchctl kickstart -k "$domain/$launchd_label"
                        ''
                      else
                        ''systemctl --user start "$service_name.service"''
                    }
                  }

                  stop_service() {
                    ${
                      if pkgs.stdenv.hostPlatform.isDarwin then
                        ''
                          domain="gui/$(id -u)"
                          if /bin/launchctl print "$domain/$launchd_label" >/dev/null 2>&1; then
                            /bin/launchctl bootout "$domain/$launchd_label"
                          fi
                        ''
                      else
                        ''systemctl --user stop "$service_name.service"''
                    }
                  }

                  case "$action" in
                    auth)
                      if [ "$mounted" = true ]; then
                        echo "Stop the mount before changing its authentication: gdrive stop $account_name" >&2
                        exit 1
                      fi
                      install -d -m0700 ${lib.escapeShellArg configDirectory}
                      umask 077
                      if [ "$remote_configured" = true ]; then
                        echo "$account_name: is already configured; run: gdrive reauth $account_name" >&2
                        exit 1
                      fi
                      echo "Starting Google authorization for $account_email using rclone's built-in OAuth client."
                      rclone --config "$config_path" config create \
                        "$account_name" drive \
                        scope drive \
                        config_is_local ${if cfg.localBrowser then "true" else "false"}
                      if [ ! -f "$config_path" ]; then
                        echo "Authentication did not create $config_path." >&2
                        exit 1
                      fi
                      chmod 0600 "$config_path"
                      if ! rclone --config "$config_path" listremotes | grep -Fxq "$account_name:"; then
                        echo "Authentication did not create the required $account_name: remote." >&2
                        exit 1
                      fi
                      remote_configured=true
                      start_service
                      ;;
                    reauth)
                      if [ "$remote_configured" != true ]; then
                        echo "$account_name: is not configured; run: gdrive auth $account_name" >&2
                        exit 1
                      fi
                      stop_service
                      rclone --config "$config_path" config reconnect "$account_name:"
                      chmod 0600 "$config_path"
                      start_service
                      ;;
                    start)
                      start_service
                      ;;
                    stop)
                      stop_service
                      ;;
                    status)
                      echo "$account_name account: $account_email"
                      if [ -r "$config_path" ]; then
                        echo "$account_name config: present"
                      else
                        echo "$account_name config: missing"
                      fi
                      if [ "$remote_configured" = true ]; then
                        echo "$account_name remote: configured"
                      else
                        echo "$account_name remote: missing"
                      fi
                      if [ "$mounted" = true ]; then
                        echo "$account_name mount: active at $mount_point"
                      else
                        echo "$account_name mount: inactive"
                        if [ -d "$mount_point" ] && find "$mount_point" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
                          echo "$account_name mount point: contains unexpected local files"
                        fi
                      fi
                      if [ -d "$cache_directory" ]; then
                        echo "$account_name cache: $(du -sh "$cache_directory" | cut -f1)"
                      else
                        echo "$account_name cache: absent"
                      fi
                      ${
                        if pkgs.stdenv.hostPlatform.isDarwin then
                          ''
                            domain="gui/$(id -u)"
                            if service_status=$(/bin/launchctl print "$domain/$launchd_label" 2>/dev/null); then
                              if printf '%s\n' "$service_status" | grep -Fq "state = running"; then
                                echo "$account_name service: active"
                              else
                                echo "$account_name service: loaded but inactive"
                              fi
                            else
                              echo "$account_name service: unloaded"
                            fi
                          ''
                        else
                          ''
                            if systemctl --user is-active --quiet "$service_name.service"; then
                              echo "$account_name service: active"
                            else
                              echo "$account_name service: inactive"
                            fi
                          ''
                      }
                      ;;
                    logs)
                      if [ -r "$log_path" ]; then
                        tail -n 100 "$log_path"
                      else
                        echo "No rclone log exists yet at $log_path"
                      fi
                      ;;
                    *)
                      cat >&2 <<'EOF'
                  Usage:
                    gdrive auth <account>
                    gdrive reauth <account>
                    gdrive start <account>
                    gdrive stop <account>
                    gdrive status [account]
                    gdrive logs <account>
                    gdrive list
                  EOF
                      exit 2
                      ;;
                  esac
                '';
              })
            ];
            activation.googleDriveDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              run install -d -m0700 ${lib.escapeShellArg configDirectory}
              run install -d -m0700 ${lib.escapeShellArg mountRoot}
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (_: account: ''
                  run install -d -m0700 ${lib.escapeShellArg account.cacheDirectory}
                  run install -d -m0700 ${lib.escapeShellArg account.stateDirectory}
                  if [ ! -d ${lib.escapeShellArg account.mountPoint} ]; then
                    run install -d -m0500 ${lib.escapeShellArg account.mountPoint}
                  else
                    mount_point=${lib.escapeShellArg account.mountPoint}
                    if ! ${account.mountCheck}; then
                      run chmod 0500 ${lib.escapeShellArg account.mountPoint}
                    fi
                  fi
                '') configuredAccounts
              )}
            '';
          };
          programs.rclone.enable = true;
          systemd.user.services = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) (
            lib.mapAttrs' (_: account: {
              name = account.serviceName;
              value = {
                Unit.Description = "Google Drive mount for ${account.email}";
                Service = {
                  ExecStart = lib.getExe account.mountRunner;
                  Restart = "on-failure";
                  RestartSec = 10;
                };
                Install.WantedBy = [ "default.target" ];
              };
            }) configuredAccounts
          );
          launchd.agents = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
            lib.mapAttrs' (_: account: {
              name = account.serviceName;
              value = {
                enable = true;
                config = {
                  ProgramArguments = [ (lib.getExe account.mountRunner) ];
                  RunAtLoad = true;
                  KeepAlive = {
                    SuccessfulExit = false;
                    Crashed = true;
                  };
                  ProcessType = "Background";
                  ThrottleInterval = 10;
                  StandardOutPath = "${account.stateDirectory}/launcher.log";
                  StandardErrorPath = "${account.stateDirectory}/launcher.error.log";
                };
              };
            }) configuredAccounts
          );
        };
      };
  };
}
