{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.hosts.darwin.alpha = {
    hostPlatform = "aarch64-darwin";
    profiles = [
      "graphical"
      "development"
    ];
    modules = [
      cfg.modules.darwin.user-rafiq
      cfg.modules.darwin.rosetta-builder
    ];
  };
  config.flake.hosts.nixos.nemesis = {
    hostPlatform = "x86_64-linux";
    profiles = [
      "graphical"
      "development"
    ];
    modules = [
      cfg.modules.nixos.user-rafiq
      cfg.modules.nixos.nvidia-graphics
      cfg.modules.nixos.steam
      cfg.modules.nixos.prismlauncher
      cfg.modules.nixos.daily-midnight-poweroff
      (
        {
          config,
          pkgs,
          lib,
          modulesPath,
          ...
        }:
        {
          imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
          hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
          boot = {
            initrd.availableKernelModules = [
              "nvme"
              "xhci_pci"
              "ahci"
              "usbhid"
              "usb_storage"
              "sd_mod"
            ];
            kernelModules = [ "kvm-amd" ];
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
                "uid=1000"
                "umask=022"
                "iocharset=utf8"
                "windows_names"
                "nofail"
                "x-systemd.automount"
                "x-systemd.idle-timeout=10min"
              ];
            };
          };
        }
      )
    ];
  };
}
