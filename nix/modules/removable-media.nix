{
  config.flake.modules.nixos.removable-media =
    { primaryUser, ... }:
    {
      # UDisks and udiskie mount removable block devices under /run/media/$USER.
      services = {
        udisks2.enable = true;
        gvfs.enable = true;
      };

      # GVfs uses libgphoto2 to expose PTP cameras such as Nikon Coolpix models.
      programs.gphoto2.enable = true;
      users.users.${primaryUser.name}.extraGroups = [ "camera" ];

      home-manager.sharedModules = [
        {
          services.udiskie = {
            enable = true;
            automount = true;
            notify = true;
            tray = "never";
          };
        }
      ];
    };
}
