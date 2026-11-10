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
    vm = {
      enable = true;
      profiles = [ "graphical" ];
    };
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
          consoleLogLevel = 3;
          initrd.verbose = false;
          kernelParams = [
            "quiet"
            "udev.log_level=3"
            "systemd.show_status=auto"
            "rd.systemd.show_status=auto"
            "fbcon=nodefer"
            "vt.global_cursor_default=0"
          ];
          loader = {
            timeout = 0;
            systemd-boot = {
              enable = true;
              edk2-uefi-shell.enable = true;
            };
            efi.canTouchEfiVariables = true;
          };
          kernelPackages = pkgs.linuxPackages_latest;
          plymouth = {
            enable = true;
            theme = "black";
            themePackages = [ cfg.packages.${pkgs.stdenv.hostPlatform.system}.plymouth-theme-black ];
          };
        };
      };
    machineModules = [
      cfg.modules.nixos.agent-browser-shared
      cfg.modules.nixos.nvidia-graphics
      cfg.modules.nixos.windows-vm
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
          ensureProfiles.profiles = {
            # Keep the direct profile as an explicit recovery path. The bridge
            # is the normal host connection while zagreus is available.
            wired = {
              connection = {
                id = "wired";
                type = "ethernet";
                interface-name = "enp12s0";
                uuid = "221e9127-902c-483a-bbc4-7d2403b7dce9";
                autoconnect = false;
                autoconnect-priority = 50;
              };
              ethernet.mac-address = "74:56:3C:35:AB:E5";
              ipv4.method = "auto";
              ipv6 = {
                method = "auto";
                addr-gen-mode = "stable-privacy";
              };
            };
            lan-bridge = {
              connection = {
                id = "lan-bridge";
                uuid = "90f94c60-a8ea-49c4-8867-12b7ec620f77";
                type = "bridge";
                interface-name = "br0";
                autoconnect = true;
                autoconnect-priority = 100;
              };
              bridge = {
                stp = false;
                mac-address = "74:56:3C:35:AB:E5";
              };
              ipv4.method = "auto";
              ipv6 = {
                method = "auto";
                addr-gen-mode = "stable-privacy";
              };
            };
            lan-bridge-port = {
              connection = {
                id = "lan-bridge-port";
                uuid = "19af3f2e-63f4-47ff-a4a7-91eb30648b22";
                type = "ethernet";
                interface-name = "enp12s0";
                autoconnect = true;
                controller = "br0";
                port-type = "bridge";
              };
              ethernet.mac-address = "74:56:3C:35:AB:E5";
            };
          };
          settings.main.no-auto-default = "74:56:3C:35:AB:E5";
        };
        # The VM ownership hook stops this service before releasing the physical
        # Windows disk to QEMU and restores it after a clean guest shutdown.
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
