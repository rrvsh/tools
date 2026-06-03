{
  config.flake.modules.darwin.nix-settings = {
    nix.settings = {
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
    };
  };
  config.flake.modules.nixos.nix-settings = {
    nix.settings = {
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
    };
  };
}
