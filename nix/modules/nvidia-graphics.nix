{
  config.flake.modules.nixos.nvidia-graphics =
    { config, lib, ... }:
    {
      nixpkgs.config.allowUnfreePredicate = lib.mkForce (
        pkg:
        builtins.elem (lib.strings.getName pkg) [
          "nvidia-kernel-modules"
          "nvidia-persistenced"
          "nvidia-settings"
          "nvidia-x11"
          "steam"
          "steam-original"
          "steam-run"
          "steam-unwrapped"
        ]
      );
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };
        nvidia = {
          modesetting.enable = true;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
          open = false;
        };
      };
      environment.sessionVariables = {
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        LIBVA_DRIVER_NAME = "nvidia";
      };
    };
}
