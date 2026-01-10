impersonate:
  gcloud auth application-default print-access-token || gcloud auth application-default login --impersonate-service-account=infra-ci@rrvsh-production.iam.gserviceaccount.com

setup:
  just impersonate
  tofu -chdir=tf init -reconfigure

reset:
  gcloud auth application-default revoke

plan-tf:
  just setup
  tofu -chdir=tf plan

apply-tf:
  just setup
  tofu -chdir=tf apply

run-docker:
  docker image load -i $(nix build .#packages.aarch64-linux.rrvsh-image --print-out-paths)
  docker run --rm -p 3000:3000 rrvsh:latest

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
