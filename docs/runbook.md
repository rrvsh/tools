# runbook.md

## to kill Hyprland from an SSH session

pkill .Hyprland-wrapp

## generating an age key to edit sops-nix secrets

```bash
# linux
ssh-to-age -private-key -i $HOME/.ssh/id_ed25519 > $HOME/.config/sops/age/keys.txt
age-keygen -y $HOME/.config/sops/age/keys.txt

# darwin
ssh-to-age -private-key -i $HOME/.ssh/id_ed25519 > "$HOME/Library/Application Support/sops/age/keys.txt"
age-keygen -y "$HOME/Library/Application Support/sops/age/keys.txt"
```

## generating ssh pubkey

`ssh-keygen -f $HOME/.ssh/id_ed25519 -y > $HOME/.ssh/id_ed25519.pub`

## clearing macos dns cache

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```
