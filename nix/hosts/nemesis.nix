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
            (modulesPath + "/installer/scan/not-detected.nix")
            cfg.modules.nixos.passwordless-sudo
            cfg.modules.nixos.nix-settings
            cfg.modules.nixos.ssh-config
            cfg.modules.nixos.tailscale-config
            cfg.modules.nixos.audio-config
            cfg.modules.nixos.sops-config
            cfg.modules.nixos.steam
            cfg.modules.nixos.nvidia-graphics
            cfg.modules.nixos.waybar
            cfg.modules.nixos.hyprland
          ];
          networking.hostName = "nemesis";
          time.timeZone = "Asia/Singapore";
          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
          nix.settings = {
            extra-substituters = [
              "https://nix-community.cachix.org"
            ];
            extra-trusted-public-keys = [
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
          };
          system.stateVersion = "26.05";
          security.polkit.enable = true;
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
            i2c.enable = true;
          };
          networking.networkmanager.enable = true;
          programs.dconf.enable = true;
        }
      )
    ];
  };
}
