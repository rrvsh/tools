# common tools

watch-site:
  bacon run -- --manifest-path rs/Cargo.toml --package site

watch-clippy:
  bacon clippy -- --manifest-path rs/Cargo.toml --all

run-docker:
  docker load -i $(nix build .#packages.aarch64-linux.site-image --print-out-paths)
  docker run --rm -e PORT=8080 -p 8080:8080 site:latest

rb:
  just format-nix
  just lint-nix
  just check-nix
  just _rb-{{os()}}

deploy-rrv-sh:
  nix build .#nixosConfigurations.hermes.config.system.build.toplevel
  nix copy --no-check-sigs --to ssh-ng://root@rrv.sh ./result
  ssh root@rrv.sh "$(readlink -f result)/bin/switch-to-configuration switch"

register-aenyrathia-deploy-key:
  #!/usr/bin/env bash
  set -euo pipefail
  repo="rrvsh/aenyrathia"
  title="orichalcum-aenyrathia"
  public_key="$(ssh root@aenyrathia.wiki 'cat /var/lib/aenyrathia/.ssh/id_ed25519.pub')"
  public_fingerprint="$(ssh-keygen -lf - <<< "$public_key" | awk '{print $2}')"
  existing_keys="$(gh api "repos/$repo/keys" --paginate --jq ".[] | select(.title == \"$title\") | [.id, .key] | @tsv")"
  if [ -n "$existing_keys" ]; then
    while IFS=$'\t' read -r id existing_key; do
      existing_fingerprint="$(ssh-keygen -lf - <<< "$existing_key" | awk '{print $2}')"
      if [ "$existing_fingerprint" = "$public_fingerprint" ]; then
        echo "Deploy key '$title' already registered for $repo as id $id."
        exit 0
      fi
    done <<< "$existing_keys"
    echo "Deploy key title '$title' already exists for $repo, but with a different key." >&2
    echo "Delete or rename the existing key before rerunning this recipe." >&2
    exit 1
  fi
  gh api --method POST "repos/$repo/keys" -f title="$title" -f key="$public_key" -F read_only=false >/dev/null
  echo "Registered read/write deploy key '$title' for $repo."

_rb-macos:
  nh darwin switch .

_rb-linux:
  nh os switch .
  just clear-systemd-boot-entry-overrides

clear-systemd-boot-entry-overrides:
  sudo bash -lc 'for v in /sys/firmware/efi/efivars/LoaderEntryDefault-* /sys/firmware/efi/efivars/LoaderEntryPreferred-*; do [ -e "$v" ] || continue; chattr -i "$v" 2>/dev/null || true; rm -f "$v" || true; done'

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
