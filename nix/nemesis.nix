{ inputs, config, ... }:
let
  cfg = config.flake;
  inherit (inputs.nixpkgs.lib) nixosSystem;
in
{
  config.flake.nixosConfigurations.nemesis = nixosSystem {
    modules = [
      cfg.modules.nixos.default
      cfg.modules.nixos.rafiq
      (
        {
          pkgs,
          config,
          lib,
          modulesPath,
          ...
        }:
        {
          networking.hostName = "nemesis";

          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
            cfg.modules.nixos.hyprland
            cfg.modules.nixos.nvidia
            cfg.modules.nixos.pipewire
            cfg.modules.nixos.steam
            cfg.modules.nixos.i2c
          ];

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
          };

          fileSystems."/" = {
            device = "/dev/disk/by-uuid/13ad8c18-69ff-4288-8dec-bc50f0f5374c";
            fsType = "ext4";
          };

          fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/BC86-01BB";
            fsType = "vfat";
            options = [
              "fmask=0077"
              "dmask=0077"
            ];
          };

          swapDevices = [ ];

          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
          hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

          boot = {
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

          networking.networkmanager.enable = true;
          time.timeZone = "Asia/Singapore";
        }
      )
    ];
  };
}
