let
  settings = {
    KbdInteractiveAuthentication = false;
    PasswordAuthentication = false;
    PermitRootLogin = "prohibit-password";
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
    home-manager.sharedModules = [
      (
        { config, ... }:
        {
          launchd.agents.ssh-add = {
            enable = true;
            config = {
              ProgramArguments = [
                "/bin/sh"
                "-c"
                "ssh-add ${config.home.homeDirectory}/.ssh/id_ed25519"
              ];
              RunAtLoad = true;
              KeepAlive = false;
            };
          };
        }
      )
    ];
  };
  config.flake.modules.nixos.ssh-config =
    { primaryUser, ... }:
    {
      services.openssh = {
        enable = true;
        inherit settings;
      };
      users.users.root.openssh.authorizedKeys.keys = primaryUser.sshAuthorizedKeys;
      home-manager.sharedModules = [
        (
          { pkgs, config, ... }:
          {
            systemd.user.services.ssh-add = {
              Unit = {
                Description = "Add SSH key to agent on login";
                After = [ "ssh-agent.service" ];
              };
              Service = {
                Type = "oneshot";
                ExecStart = "${pkgs.openssh}/bin/ssh-add ${config.home.homeDirectory}/.ssh/id_ed25519";
                RemainAfterExit = true;
              };
              Install.WantedBy = [ "default.target" ];
            };
          }
        )
      ];
    };

}
