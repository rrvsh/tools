# runbook.md

## to kill Hyprland from an SSH session

pkill .Hyprland-wrapp

## stacked diffs

To resign one commit per branch:
git fetch origin prime && git rebase -i origin/prime && git commit --amend '-S' && git rebase --continue && git push -f

## generating an age key to edit sops-nix secrets

```bash
# linux
ssh-to-age -private-key -i $HOME/.ssh/id_ed25519 > $HOME/.config/sops/age/keys.txt
age-keygen -y $HOME/.config/sops/age/keys.txt

# darwin
ssh-to-age -private-key -i $HOME/.ssh/id_ed25519 > "$HOME/Library/Application Support/sops/age/keys.txt"
age-keygen -y "$HOME/Library/Application Support/sops/age/keys.txt"
```

## referencing home directories

```nix
config.home.homeDirectory # home manager
config.users.users.rafiq.home # nixos/darwin
```

## random

reload direnv or nix develop: `direnv reload`

Home paths in Nix/Home Manager: see `nix/README.md` (“Referencing home directories”) for the preferred patterns.

rg --no-binary --hidden --null -l '' \
      | tr '\0' '\n' \
      | grep -vE '^\.git/' \
      | grep -vE '/(\.direnv|result|tmp|node_modules)/' \
      | while read -l f
      echo "\n==== $f ====\n"
      cat "$f"
  end | pbcopy

nix store info --store ssh://eu.nixbuild.net

nix run nixpkgs#darwin.linux-builder

sudo darwin-rebuild switch --flake

ssh-keygen -f $HOME/.ssh/id_ed25519 -y > $HOME/.ssh/id_ed25519.pub

mkdir -p $HOME/Library/Application\ Support/sops/age && ssh-to-age -private-key -i $HOME/.ssh/id_ed25519 > $HOME/Library/Application\ Support/sops/age/keys.txt

mkdir -p $HOME/.config/sops/age && ssh-to-age -private-key -i $HOME/.ssh/id_ed25519 > $HOME/.config/sops/age/keys.txt

nix shell nixpkgs#qemu -c qemu-system-aarch64 \
   -machine virt,highmem=off \
   -cpu host -accel hvf \
   -m 3072 \
   -drive id=hd0,if=none,format=qcow2,file=./nixos.qcow2 \
   -device virtio-blk-device,drive=hd0 \
   -device virtio-net-pci,netdev=net0 \
   -netdev user,id=net0,hostfwd=tcp::2222-:22 \
   -bios /nix/store/1gfvpb90c3xpjxf4r2k2br62d0h0zhgc-qemu-10.1.2/share/qemu/edk2-aarch64-code.fd \
   -nographic

nix build .#nixosConfigurations.pi.config.formats.sd-aarch64
caligula burn result/nixos-image-sd-card-25.11.20251108.b6a8526-aarch64-linux.img.zst

## Clear MacOS DNS Cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
