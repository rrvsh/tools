{ config, primaryUsers, ... }:
let
  cfg = config.flake;
in
{
  config.flake.hosts.nixos.mercury = {
    hostPlatform = "x86_64-linux";
    primaryUser = primaryUsers.rafiq;
    profiles = [ "development" ];
    modules = [ cfg.modules.nixos.user-primary ];
    extraConfig = {
      home-manager.sharedModules = [
        { services.google-drive.localBrowser = false; }
      ];
    };
    machineModules = [ cfg.modules.nixos.vultr-vps ];
    extraMachineConfig =
      { lib, ... }:
      {
        boot.initrd = {
          availableKernelModules = [
            "ata_piix"
            "uhci_hcd"
            "xen_blkfront"
            "vmw_pvscsi"
          ];
          kernelModules = [ "nvme" ];
        };
        fileSystems = {
          "/" = {
            device = "/dev/disk/by-uuid/002fb038-d031-48e5-8f88-b5d14a4bac35";
            fsType = "ext4";
          };
          "/boot/efi" = {
            device = "/dev/disk/by-uuid/BB9B-6199";
            fsType = "vfat";
          };
        };
        networking.firewall = {
          allowPing = false;
          interfaces.tailscale0.allowedTCPPorts = [ 22 ];
        };
        nix = {
          gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 14d";
          };
          settings = {
            min-free = 5 * 1024 * 1024 * 1024;
            max-free = 10 * 1024 * 1024 * 1024;
          };
        };
        services = {
          journald.settings.Journal.SystemMaxUse = "512M";
          openssh = {
            openFirewall = lib.mkForce false;
            settings.PermitRootLogin = lib.mkForce "no";
          };
          tailscale.authKeyFile = lib.mkForce null;
        };
        system.stateVersion = lib.mkForce "23.11";
        zramSwap.enable = true;
      };
  };
}
