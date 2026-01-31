{
  config.flake.hosts.nixos.nemesis = {
    modules = [
      (
        {
          pkgs,
          ...
        }:
        {
          boot = {
            loader.systemd-boot = {
              enable = true;
              edk2-uefi-shell.enable = true;
            };
            loader.efi.canTouchEfiVariables = true;
            kernelPackages = pkgs.linuxPackages_latest;
          };

          networking.hostName = "nemesis";
          networking.networkmanager.enable = true;

          time.timeZone = "Asia/Singapore";

          services.openssh.enable = true;

          system.stateVersion = "25.11";
        }
      )
      (
        {
          config,
          lib,
          modulesPath,
          ...
        }:
        {
          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
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
        }
      )
    ];
  };
}
