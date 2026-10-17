{
  config.flake.modules.nixos.windows-vm =
    { primaryUser, ... }:
    {
      users.users.${primaryUser.name}.extraGroups = [ "libvirtd" ];

      virtualisation.libvirtd = {
        enable = true;
        onBoot = "ignore";
        onShutdown = "shutdown";
        qemu.runAsRoot = false;
      };
    };
}
