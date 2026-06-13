{
  config.flake.modules.nixos."usb-automount" =
    { pkgs, ... }:
    {
      # udisks2 provides the DBus service and udisksctl CLI used by tools such as
      # zmk-nix's UF2 flasher. udiskie is the per-user automounter that mounts
      # removable drives under /run/media/$USER when they appear.
      services = {
        udisks2.enable = true;
        gvfs.enable = true;
      };

      environment.systemPackages = with pkgs; [
        udisks2
        udiskie
        usbutils
      ];

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
