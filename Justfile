rb:
  just nice
  just check
  nh darwin switch .

nice: format lint
check: check-gha check-lua check-nix test

format: format-gha format-lua format-nix
lint: lint-lua lint-nix
test: test-nix

format-gha:
  zizmor . --gh-token $(gh auth token) --fix

format-lua:
  stylua .

format-nix:
  treefmt

lint-lua:
  luacheck $(git ls-files '*.lua')

lint-nix:
  # catches stuff that would fail in ci but not caught by statix fix
  statix check
  statix fix
  deadnix --edit

test-nix:
  nix flake check --all-systems

check-gha:
  zizmor . --gh-token $(gh auth token)

check-lua:
  stylua --check .

check-nix:
  treefmt --ci
  statix check
  deadnix
