{
  flake = {
    users.users.rafiq = {
      primary = true;
      fullName = "Mohammad Rafiq";
      email = "rafiq@rrv.sh";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
      shell = "fish";
      defaultBranchName = "prime";
      browser = "firefox";
    };
    devenv =
      pkgs: with pkgs; [
        deadnix
        just
        nh
        nixfmt-tree
        sops
        statix
        stylua
        zizmor
        luajitPackages.luacheck
      ];
  };
}
