check: test

test: test-nix

test-nix:
  nix flake check --all-systems
