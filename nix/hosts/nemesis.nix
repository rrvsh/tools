{
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
in
{
  config.flake.nixosConfigurations.nemesis = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      cfg.modules.nixos.rafiq
      (
        {
          config,
          pkgs,
          lib,
          modulesPath,
          ...
        }:
        let
          uid = toString config.users.users.rafiq.uid;
          runtimeDir = "/run/user/${uid}";
          idleStateFile = "${runtimeDir}/hypridle-state";
        in
        {
          imports = [
            inputs.sops-nix.nixosModules.sops
            inputs.hyprland.nixosModules.default
            (modulesPath + "/installer/scan/not-detected.nix")
            cfg.modules.nixos.passwordless-sudo
          ];
          networking.hostName = "nemesis";
          time.timeZone = "Asia/Singapore";
          nixpkgs = {
            hostPlatform = lib.mkDefault "x86_64-linux";
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (lib.strings.getName pkg) [
                "nvidia-kernel-modules"
                "nvidia-persistenced"
                "nvidia-settings"
                "nvidia-x11"
                "steam"
                "steam-original"
                "steam-run"
                "steam-unwrapped"
              ];
          };
          nix.settings = {
            experimental-features = "nix-command flakes";
            eval-cache = true;
            fallback = false;
            use-registries = false;
            flake-registry = "";
            tarball-ttl = 86400;
            connect-timeout = 10;
            http-connections = 50;
            max-substitution-jobs = 32;
            narinfo-cache-negative-ttl = 60;
            max-jobs = "auto";
            cores = 0;
            builders-use-substitutes = true;
            allow-import-from-derivation = false;
            extra-substituters = [
              "https://nix-community.cachix.org"
              "https://hyprland.cachix.org"
            ];
            extra-trusted-public-keys = [
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            ];
          };
          system.stateVersion = "26.05";
          security = {
            polkit.enable = true;
            rtkit.enable = true;
          };
          services = {
            openssh = {
              enable = true;
              settings = {
                KbdInteractiveAuthentication = false;
                PasswordAuthentication = false;
                PermitRootLogin = "no";
              };
            };
            tailscale = {
              enable = true;
              authKeyFile = config.sops.secrets."tailscale/authkey".path;
            };
            xserver.videoDrivers = [ "nvidia" ];
            pipewire = {
              enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
              pulse.enable = true;
              jack.enable = true;
              wireplumber.enable = true;
            };
          };
          systemd.services.daily-midnight-poweroff = {
            description = "Power off nemesis daily at midnight";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "daily-midnight-poweroff" ''
                set -euo pipefail

                log() {
                  printf '%s %s\n' "$(date '+%F %T %Z')" "$1"
                }
                read_state() {
                  if [ -r "$state_file" ]; then
                    ${pkgs.coreutils}/bin/cat "$state_file" || true
                    return
                  fi
                  printf 'unknown'
                }
                state_file="${idleStateFile}"
                runtime_dir="${runtimeDir}"

                state="$(read_state)"
                log "midnight check state=$state file=$state_file"
                if [ "$state" != "idle" ]; then
                  log "not idle at 00:00, exiting"
                  exit 0
                fi

                ${pkgs.util-linux}/bin/runuser -u rafiq -- env \
                  XDG_RUNTIME_DIR="$runtime_dir" \
                  DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
                  ${pkgs.libnotify}/bin/notify-send \
                  "Midnight auto-shutdown" \
                  "Idle detected. Shutting down in 1 minute unless activity resumes." \
                  || true
                log "idle at 00:00, notification sent, waiting 60s"
                ${pkgs.coreutils}/bin/sleep 60

                state_after="$(read_state)"
                log "post-wait check state=$state_after file=$state_file"
                if [ "$state_after" = "idle" ]; then
                  log "still idle at 00:01, powering off now"
                  ${pkgs.systemd}/bin/systemctl poweroff
                fi
                log "activity resumed before 00:01, skipping shutdown"
              '';
            };
            startAt = "*-*-* 00:00:00";
          };
          sops.secrets."tailscale/authkey" = {
            sopsFile = cfg.paths.root + "/sops/tailscale.yaml";
          };
          boot = {
            initrd.availableKernelModules = [
              "nvme"
              "xhci_pci"
              "ahci"
              "usbhid"
              "usb_storage"
              "sd_mod"
            ];
            initrd.kernelModules = [ ];
            kernelModules = [ "kvm-amd" ];
            extraModulePackages = [ ];
            loader.systemd-boot = {
              enable = true;
              edk2-uefi-shell.enable = true;
              windows."11-pro" = {
                title = "Windows 11 Pro";
                efiDeviceHandle = "HD0d";
              };
            };
            loader.efi.canTouchEfiVariables = true;
            kernelPackages = pkgs.linuxPackages_latest;
          };
          fileSystems = {
            "/" = {
              device = "/dev/disk/by-uuid/13ad8c18-69ff-4288-8dec-bc50f0f5374c";
              fsType = "ext4";
            };
            "/boot" = {
              device = "/dev/disk/by-uuid/BC86-01BB";
              fsType = "vfat";
              options = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
            "/mnt/windows" = {
              device = "/dev/disk/by-uuid/0EA45F71A45F59F3";
              fsType = "ntfs3";
              options = [
                "rw"
                "uid=${uid}"
                "umask=022"
                "iocharset=utf8"
                "windows_names"
                "nofail"
                "x-systemd.automount"
                "x-systemd.idle-timeout=10min"
              ];
            };
          };
          swapDevices = [ ];
          hardware = {
            cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
            graphics = {
              enable = true;
              enable32Bit = true;
            };
            nvidia = {
              modesetting.enable = true;
              nvidiaSettings = true;
              package = config.boot.kernelPackages.nvidiaPackages.stable;
              open = false;
            };
            i2c.enable = true;
          };
          networking.networkmanager.enable = true;
          environment.sessionVariables = {
            GBM_BACKEND = "nvidia-drm";
            __GLX_VENDOR_LIBRARY_NAME = "nvidia";
            LIBVA_DRIVER_NAME = "nvidia";
            NIXOS_OZONE_WL = "1";
          };
          fonts.packages = with pkgs; [
            nerd-fonts.jetbrains-mono
            monocraft
          ];
          programs = {
            hyprland = {
              enable = true;
              xwayland.enable = true;
              package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
              portalPackage =
                inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
            };
            dconf.enable = true;
            steam = {
              enable = true;
              remotePlay.openFirewall = true;
              dedicatedServer.openFirewall = true;
              localNetworkGameTransfers.openFirewall = true;
            };
            gamemode.enable = true;
            gamescope.enable = true;
          };
          assertions = [
            {
              assertion = config.networking.hostName != "";
              message = "Hyprland module expects a hostName.";
            }
          ];
          xdg.portal.enable = true;
          xdg.portal.extraPortals = [ config.programs.hyprland.portalPackage ];
        }
      )
    ];
  };
}
