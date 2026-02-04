{
  config.flake = {
    allowedUnfreePackages = [
      "nvidia-persistenced"
      "nvidia-settings"
      "nvidia-x11"
    ];
    modules.nixos.nvidia =
      { config, ... }:
      {
        services.xserver.videoDrivers = [ "nvidia" ];
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };
        hardware.nvidia = {
          modesetting.enable = true;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
          open = true;
        };
        environment.sessionVariables = {
          GBM_BACKEND = "nvidia-drm";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          LIBVA_DRIVER_NAME = "nvidia";
        };
      };
  };
}
