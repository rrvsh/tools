# options

this should provide a public API for easily defining the module outputs of higher level modules.

- `hosts.darwin.<name>` -> used to name and configure darwin machines
- `users.users.<name>` -> used to name and configure users
- `modules.darwin.default` -> used in builders/darwinConfigurations.nix in all darwin machines

## RULES:

- the folder structure should match the nesting of the option.
  for example:

    ```nix
    # alpha.nix
    {
      config.flake.hosts.darwin.alpha.platform = "aarch64-darwin";
    }
    # options/hosts/default.nix
    {
      ...
      config.flake.modules.darwin.default =
        { hostConfig, ... }:
        {
          nixpkgs.hostPlatform = hostConfig.platform;
        };
      ...
    }

    # rafiq.nix
    {
      config.flake.users.users.rafiq = {
        pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
      };
    }
    # options/users/default.nix
    {
      ...
      config.flake.modules.darwin.default = {
        users.users = mapAttrs (username: userConfig: {
          home = "/Users/${username}"; # prefer setting home here; see nix/README.md for home path guidance
          openssh.authorizedKeys.keys = [ userConfig.pubkey ];
        }) config.flake.users.users;
      };
      ...
    }

    ```
- all common options (i.e. default, every machine should have) should be in a `default.nix`.
