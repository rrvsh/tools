watch-site:
  bacon run -- --manifest-path rs/Cargo.toml --package site

watch-clippy:
  bacon clippy -- --manifest-path rs/Cargo.toml --all

setup:
  cp .env.template .env
  aws sts get-caller-identity > /dev/null 2>&1 || aws configure
  colima status > /dev/null 2>&1 || colima start

run-docker:
  docker load -i $(nix build .#packages.aarch64-linux.site-image --print-out-paths)
  docker run --rm -e PORT=8080 -p 8080:8080 site:latest

rb:
  just nice
  just check
  just _rb-{{os()}}

_rb-macos:
  nh darwin switch .

_rb-linux:
  nh os switch .

nice: format lint

format: format-gha format-lua format-nix format-rs format-tf

format-gha:
  zizmor . --gh-token $(gh auth token) --fix=all

format-lua:
  stylua .

format-nix:
  treefmt

format-rs:
  cargo fmt --manifest-path rs/Cargo.toml --all

format-tf:
  tofu -chdir=tf fmt

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
  nix flake check --all-systems

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
