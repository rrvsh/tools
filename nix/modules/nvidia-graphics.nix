{
  config.flake.allowedUnfreePackages = [
    "nvidia-kernel-modules"
    "nvidia-persistenced"
    "nvidia-settings"
    "nvidia-x11"
  ];
  config.flake.modules.nixos.nvidia-graphics =
    { config, ... }:
    {
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
