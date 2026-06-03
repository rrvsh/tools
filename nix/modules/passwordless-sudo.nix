{
  config.flake.modules.darwin.passwordless-sudo = {
    security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
  };
  config.flake.modules.nixos.passwordless-sudo = {
    security.sudo.wheelNeedsPassword = false;
  };
}
