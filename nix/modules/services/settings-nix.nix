{ config, ... }:
let
  account = config.flake.accounts.rafiq;
  inherit (account) username;
  sharedNixSettings = {
    trusted-users = [ username ];
    experimental-features = "nix-command flakes";

    eval-cache = true;
    fallback = false;
    use-registries = false;
    flake-registry = "";
    tarball-ttl = 86400;

    connect-timeout = 10;
    http-connections = 50;
    max-substitution-jobs = 32;
    narinfo-cache-negative-ttl = 60;

    max-jobs = "auto";
    cores = 0;
    builders-use-substitutes = true;

    allow-import-from-derivation = false;

    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };
in
{
  config.flake = {
    modules.nixos.default = {
      nix = {
        distributedBuilds = true;
        buildMachines = [ ];
        settings = sharedNixSettings;
      };
    };
    modules.darwin.default = {
      nix = {
        distributedBuilds = true;
        buildMachines = [ ];
        settings = sharedNixSettings;
      };
    };
  };
}
