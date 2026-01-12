run-rs:
  cargo run --manifest-path rs/Cargo.toml

rb:
  just nice
  just check
  nh darwin switch .

nice: format lint
check: check-gha check-lua check-nix check-rs test

format: format-gha format-lua format-nix format-rs
lint: lint-lua lint-nix lint-rs
test: test-nix test-rs

format-gha:
  zizmor . --gh-token $(gh auth token) --fix

format-lua:
  stylua .

format-nix:
  treefmt

format-rs:
  cargo fmt --manifest-path rs/Cargo.toml

lint-lua:
  luacheck $(git ls-files '*.lua')

lint-nix:
  # catches stuff that would fail in ci but not caught by statix fix
  statix check
  statix fix
  deadnix --edit

lint-rs:
  cargo clippy --manifest-path rs/Cargo.toml --fix --allow-dirty

test-nix:
  nix flake check --all-systems

test-rs:
  cargo test --manifest-path rs/Cargo.toml

check-gha:
  zizmor . --gh-token $(gh auth token)

check-lua:
  stylua --check .

check-nix:
  treefmt --ci
  statix check
  deadnix

check-rs:
  just test-rs
  cargo check --manifest-path rs/Cargo.toml
  cargo clippy --manifest-path rs/Cargo.toml
  cargo fmt --manifest-path rs/Cargo.toml --check
