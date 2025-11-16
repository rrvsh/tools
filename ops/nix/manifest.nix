{
  flake = {
    users.users.rafiq = {
      primary = true;
      fullName = "Mohammad Rafiq";
      email = "rafiq@rrv.sh";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
      defaultBranchName = "prime";
      apps = {
        editor = "neovim";
        shell = "fish";
        browser = "firefox";
        terminal = "ghostty";
        file-browser = "yazi";
      };
    };
  };
}
