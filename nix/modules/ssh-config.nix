let
  settings = {
    KbdInteractiveAuthentication = false;
    PasswordAuthentication = false;
    PermitRootLogin = "no";
  };
  renderValue =
    value: if builtins.isBool value then (if value then "yes" else "no") else toString value;
  renderSettings =
    settings:
    builtins.concatStringsSep "\n" (
      builtins.map (name: "${name} ${renderValue settings.${name}}") (builtins.attrNames settings)
    );
in
{
  config.flake.modules.darwin.ssh-config = {
    services.openssh = {
      enable = true;
      extraConfig = renderSettings settings;
    };
  };

  config.flake.modules.nixos.ssh-config = {
    services.openssh = {
      enable = true;
      inherit settings;
    };
  };
}
