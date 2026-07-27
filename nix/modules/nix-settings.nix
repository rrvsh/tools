let
  commonSettings = {
    experimental-features = "nix-command flakes";
    use-registries = false; # Avoid implicit flake refs.
    flake-registry = ""; # Disable global registry.
    tarball-ttl = 86400; # Refresh tarballs every 24 hours.
    connect-timeout = 10; # 10 second timeout for binary caches.
    http-connections = 50; # 50 parallel connections for downloads.
    max-substitution-jobs = 32; # 32 parallel cache fetches.
    narinfo-cache-negative-ttl = 60; # Retry cache misses after 60s.
    max-jobs = "auto"; # Build one job per CPU.
    builders-use-substitutes = true; # Let remote builders use their own configured caches.
    allow-import-from-derivation = false; # Disallow building derivations during evaluation.
  };
  module = {
    nix.settings = commonSettings;
  };
in
{
  config.flake.modules.darwin.nix-settings = module;
  config.flake.modules.nixos.nix-settings = module;
}
