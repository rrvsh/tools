check: format lint test

nice: format lint

format: format-nix format-gha

format-nix:
  treefmt

format-gha:
  zizmor . --gh-token $(gh auth token) --fix

lint: lint-nix

lint-nix:
  statix check
  statix fix
  deadnix -e

test: test-nix

test-nix:
  nix flake check --all-systems
