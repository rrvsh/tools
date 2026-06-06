{ config, ... }:
let
  cfg = config.flake;
  rrvshSshAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAgeb4QgH9YPUfS9lG2GMC1/fnxaxCX2F+lbgfxN1d6"
  ];
  rafiq = {
    name = "rafiq";
    fullName = "Mohammad Rafiq";
    email = "rafiq@rrv.sh";
    gitDefaultBranch = "prime";
    sshAuthorizedKeys = rrvshSshAuthorizedKeys;
  };
  binmohm = {
    name = "binmohm";
    fullName = "binmohm";
    email = "rafiq@rrv.sh";
    uid = 502;
    sshAuthorizedKeys = rrvshSshAuthorizedKeys;
  };
in
{
  config.flake.hosts.darwin = {
    alpha = {
      hostPlatform = "aarch64-darwin";
      primaryUser = rafiq;
      profiles = [
        "graphical"
        "development"
      ];
      modules = [
        cfg.modules.darwin.user-primary
        cfg.modules.darwin.rosetta-builder
      ];
    };
    auto = {
      hostPlatform = "aarch64-darwin";
      primaryUser = binmohm;
      profiles = [
        "development"
        "graphical"
      ];
      modules = [
        cfg.modules.darwin.user-primary
        cfg.modules.darwin.sudo-env-wrapper
      ];
    };
  };
  config.flake.hosts.nixos = {
    nemesis = {
      hostPlatform = "x86_64-linux";
      primaryUser = rafiq;
      profiles = [
        "graphical"
        "development"
      ];
      modules = [
        cfg.modules.nixos.user-primary
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
    "rrv.sh" = {
      hostPlatform = "x86_64-linux";
      primaryUser = rafiq;
      modules = [
        cfg.modules.nixos.user-config
        (
          {
            config,
            lib,
            pkgs,
            modulesPath,
            ...
          }:
          {
            imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
            hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
            boot = {
              kernelParams = [
                "console=ttyS1,115200n8"
                "console=tty0"
              ];
              # Vultr boots reliably from the UEFI fallback path, so use GRUB's removable EFI install
              # instead of relying on mutable EFI NVRAM entries like a local workstation can.
              loader = {
                efi = {
                  canTouchEfiVariables = false;
                  efiSysMountPoint = "/boot/efi";
                };
                grub = {
                  enable = true;
                  device = "nodev";
                  efiSupport = true;
                  efiInstallAsRemovable = true;
                  useOSProber = false;
                };
              };
            };
            fileSystems = {
              "/" = {
                device = "/dev/disk/by-uuid/cb9f37af-53d2-4510-b513-a8f8c2486445";
                fsType = "ext4";
              };
              "/boot/efi" = {
                device = "/dev/disk/by-uuid/D7A0-0D7E";
                fsType = "vfat";
              };
            };
            swapDevices = [ { device = "/swapfile"; } ];
            networking.hostName = lib.mkForce "rrv-sh";
            networking.firewall.allowedTCPPorts = [
              22
              80
              443
            ];
            security.acme = {
              acceptTerms = true;
              defaults.email = "rafiq@rrv.sh";
            };
            services.nginx = {
              enable = true;
              recommendedGzipSettings = true;
              recommendedOptimisation = true;
              recommendedProxySettings = true;
              recommendedTlsSettings = true;
              virtualHosts."rrv.sh" = {
                enableACME = true;
                forceSSL = true;
                locations."/".proxyPass = "http://127.0.0.1:8080";
              };
            };
            users = {
              groups.site = { };
              users.site = {
                isSystemUser = true;
                group = "site";
                home = "/var/lib/rrv-sh";
              };
            };
            systemd.services.site = {
              description = "rrv.sh site";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                User = "site";
                Group = "site";
                ExecStart = "${cfg.packages.${pkgs.stdenv.hostPlatform.system}.site-deploy}/bin/site";
                Restart = "always";
                RestartSec = "5s";
                StateDirectory = "rrv-sh";
                WorkingDirectory = "/var/lib/rrv-sh";
              };
            };
          }
        )
      ];
    };
  };
}
