{
  config.flake.modules.nixos.vultr-vps =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
      boot.loader = {
        efi.efiSysMountPoint = "/boot/efi";
        grub = {
          device = "nodev";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };
      };
    };
}
