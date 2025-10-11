check: format lint test

nice: format lint

format: format-nix

format-nix:
  treefmt

lint: lint-nix

lint-nix:
  statix fix
  deadnix -e

test: test-nix

test-nix:
  nix flake check --all-systems
