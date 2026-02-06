{
  config.flake = {
    modules.nixos.default = {
      services.openssh.enable = true;
      services.openssh.settings = {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    modules.darwin.default = {
      services.openssh.enable = true;
      services.openssh.extraConfig = ''
        KbdInteractiveAuthentication no
        PasswordAuthentication no
        PermitRootLogin no
      '';
    };
  };
}
