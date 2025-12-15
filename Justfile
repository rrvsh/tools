nod:
  just nice
  nix-on-droid switch --flake .#perseus

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
  # if not authed to github just skip
  @TOKEN=$(gh auth token 2>/dev/null || true); \
  if [ -n "$TOKEN" ]; then \
    zizmor . --gh-token "$TOKEN" --fix; \
  fi

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
