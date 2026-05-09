# common tools

diff *ARGS:
  nix run .#nix-build-diff {{ ARGS }}

watch-site:
  bacon run -- --manifest-path rs/Cargo.toml --package site

watch-clippy:
  bacon clippy -- --manifest-path rs/Cargo.toml --all

run-docker:
  docker load -i $(nix build .#packages.aarch64-linux.site-image --print-out-paths)
  docker run --rm -e PORT=8080 -p 8080:8080 site:latest

rb:
  just check-nix
  just _rb-{{os()}}

_rb-macos:
  nh darwin switch .

_rb-linux:
  nh os switch .

# checks

nice: format lint

format: format-gha format-lua format-nix format-rs

format-gha:
  zizmor . --gh-token $(gh auth token) --fix=all

format-lua:
  stylua .

format-nix:
  treefmt

format-rs:
  cargo fmt --manifest-path rs/Cargo.toml --all

lint: lint-lua lint-nix lint-rs

lint-lua:
  luacheck $(git ls-files '*.lua')

lint-nix:
  # catches stuff that would fail in ci but not caught by statix fix
  statix check
  statix fix
  deadnix --edit

lint-rs:
  cargo clippy --manifest-path rs/Cargo.toml --fix --allow-dirty --all

test: test-nix test-rs

test-nix:
  if [ "${ALL_SYSTEMS:-0}" = "1" ]; then nix flake check --all-systems; else nix flake check; fi

test-rs:
  cargo test --manifest-path rs/Cargo.toml --all

check: check-gha check-lua check-nix check-rs test

check-gha:
  zizmor . --gh-token $(gh auth token)

check-lua:
  stylua --check .

check-nix:
  treefmt --ci
  statix check
  deadnix

check-rs:
  cargo clippy --manifest-path rs/Cargo.toml --all
  cargo fmt --manifest-path rs/Cargo.toml --check --all

# uncommon tools

generate-age-keys:
  just _generate-age-keys-{{os()}}

_generate-age-keys-linux:
  mkdir -p "$HOME/.config/sops/age"
  ssh-to-age -private-key -i "$HOME/.ssh/id_ed25519" \
    > "$HOME/.config/sops/age/keys.txt"
  printf "age pubkey: %s\n" \
      $(age-keygen -y "$HOME/.config/sops/age/keys.txt")

_generate-age-keys-macos:
  mkdir -p "$HOME/Library/Application Support/sops/age"
  ssh-to-age -private-key -i "$HOME/.ssh/id_ed25519" \
    > "$HOME/Library/Application Support/sops/age/keys.txt"
  printf "age pubkey: %s\n" \
      $(age-keygen -y "$HOME/Library/Application Support/sops/age/keys.txt")

generate-ssh-pubkey:
  ssh-keygen -f $HOME/.ssh/id_ed25519 -y > $HOME/.ssh/id_ed25519.pub

clear-macos-dns-cache:
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
