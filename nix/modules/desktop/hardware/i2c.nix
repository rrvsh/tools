{
  config.flake.modules.nixos.i2c = {
    # for ddcutil
    hardware.i2c.enable = true;
  };
}
