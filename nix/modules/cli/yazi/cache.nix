{
  config.flake.modules.darwin.rafiq = {
    nix.settings.extra-substituters = [ "https://yazi.cachix.org" ];
    nix.settings.extra-trusted-public-keys = [
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
    ];
  };
}
