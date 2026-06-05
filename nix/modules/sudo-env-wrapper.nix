{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.sudo-env-wrapper = {
      home-manager.sharedModules = [ cfg.modules.homeManager.sudo-env-wrapper ];
    };
    homeManager.sudo-env-wrapper =
      { pkgs, ... }:
      let
        sudoEnvPath = "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      in
      {
        home.packages = [
          (pkgs.writeShellApplication {
            name = "sudo";
            text = ''
              sudo_args=()
              cmd=()
              while [[ $# -gt 0 ]]; do
                case "$1" in
                  --)
                    sudo_args+=("$1")
                    shift
                    cmd=("$@")
                    break
                    ;;
                  -C|-D|-g|-h|-p|-R|-T|-u|--close-from|--chdir|--group|--host|--prompt|--chroot|--command-timeout|--user)
                    sudo_args+=("$1")
                    shift
                    if [[ $# -gt 0 ]]; then
                      sudo_args+=("$1")
                      shift
                    fi
                    ;;
                  --close-from=*|--chdir=*|--group=*|--host=*|--prompt=*|--chroot=*|--command-timeout=*|--user=*)
                    sudo_args+=("$1")
                    shift
                    ;;
                  -*)
                    sudo_args+=("$1")
                    shift
                    ;;
                  *)
                    cmd=("$@")
                    break
                    ;;
                esac
              done
              if [[ ''${#cmd[@]} -eq 0 ]]; then
                exec /usr/bin/sudo "''${sudo_args[@]}"
              fi
              exec /usr/bin/sudo "''${sudo_args[@]}" /usr/bin/env PATH=${sudoEnvPath} "''${cmd[@]}"
            '';
          })
        ];
      };
  };
}
