check: format lint test

nice: format-nix format-lua lint

format: format-nix format-gha format-lua

format-nix:
  treefmt

format-gha:
  gh auth token || zizmor . --gh-token $(gh auth token) --fix

format-lua:
  stylua .

lint: lint-nix

lint-nix:
  statix check
  statix fix
  deadnix -e

test: test-nix

test-nix:
  nix flake check --all-systems
