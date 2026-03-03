{
  config.flake = {
    modules.nixos.default = {
      security.sudo.wheelNeedsPassword = false;
    };
    modules.darwin.default = {
      security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
    };
  };
}
