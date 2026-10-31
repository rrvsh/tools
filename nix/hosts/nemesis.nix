{ config, primaryUsers, ... }:
let
  cfg = config.flake;
in
{
  config.flake.hosts.nixos.nemesis = {
    hostPlatform = "x86_64-linux";
    primaryUser = primaryUsers.rafiq;
    profiles = [
      "graphical"
      "development"
    ];
    modules = [ cfg.modules.nixos.user-primary ];
    extraConfig =
      { pkgs, ... }:
      {
        home-manager.sharedModules = [
          {
            programs.ghostty.settings.font-size = 13;
          }
        ];
        boot = {
          loader = {
            systemd-boot = {
              enable = true;
              edk2-uefi-shell.enable = true;
            };
            efi.canTouchEfiVariables = true;
          };
          kernelPackages = pkgs.linuxPackages_latest;
        };
      };
    machineModules = [
      cfg.modules.nixos.agent-browser-shared
      cfg.modules.nixos.nvidia-graphics
      cfg.modules.nixos.xremap
      cfg.modules.nixos.steam
      cfg.modules.nixos.prismlauncher
      cfg.modules.nixos.slskd
      cfg.modules.nixos.musicgrabber
      cfg.modules.nixos.gtnh-server
      cfg.modules.nixos.gtnh-backups
    ];
    extraMachineConfig =
      {
        config,
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
          loader.systemd-boot.windows."11-pro" = {
            title = "Windows 11 Pro";
            efiDeviceHandle = "HD0d";
          };
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
        networking.networkmanager = {
          ensureProfiles.profiles.wired = {
            connection = {
              id = "wired";
              type = "ethernet";
              interface-name = "enp12s0";
              uuid = "221e9127-902c-483a-bbc4-7d2403b7dce9";
              autoconnect = true;
              autoconnect-priority = 100;
            };
            ethernet.mac-address = "74:56:3C:35:AB:E5";
            ipv4.method = "auto";
            ipv6 = {
              method = "auto";
              addr-gen-mode = "stable-privacy";
            };
          };
          settings.main.no-auto-default = "74:56:3C:35:AB:E5";
        };
        # Samba keeps its own password database. After rebuilding, check for an
        # existing login with `sudo pdbedit -L -u rafiq`; if absent, set one
        # with `sudo smbpasswd -a rafiq` (the same login password can be used).
        services.samba = {
          enable = true;
          openFirewall = true;
          settings = {
            global."security" = "user";
            windows-profile = {
              path = "/mnt/windows/Users/rafiq";
              "valid users" = "rafiq";
              "guest ok" = "no";
              "read only" = "no";
            };
          };
        };
      };
  };
}
