# tools
caa 10032026

these are the tools i currently use :3

## notes

- `__curPos.file` will give the full evaluated path of the nix file it is called in. See [this issue](https://github.com/NixOS/nix/issues/5897#issuecomment-1012165198) for more information.
- to get home-manager logs on darwin, use `darwin-rebuild` instead of `nh`

## nemesis midnight shutdown

- hypridle writes `idle`/`active` state to `/run/user/<uid>/hypridle-state` on nemesis.
- idle timeout is `60` seconds.
- `daily-midnight-poweroff` runs at `00:00` local time daily.
- at `00:00`, if state is not `idle`, service exits immediately.
- if state is `idle`, service sends a desktop notification that shutdown will happen in 1 minute.
- service waits 60 seconds, checks state again, and powers off immediately if still `idle`.
- service logs each step to journald (view with `journalctl -u daily-midnight-poweroff.service`).

### to kill Hyprland from an SSH session

pkill .Hyprland-wrapp

## acknowledgements

- [ornicar](https://github.com/ornicar/dotfiles), for being my inspiration to start using Nix, open source, and being a full fledged software engineer
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) for teaching me how to use NixOS, flakes, and home-manager: the best damn tutorial on the internet I've seen yet
- [NotAShelf](https://github.com/notashelf/nyx) for introducing me to the idea of monorepos and custom logic (read: over-engineering) for Nix flakes
- [drupol/infra](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/) for introducing the dendritic pattern to me, and [mightyiam](https://discourse.nixos.org/t/pattern-every-file-is-a-flake-parts-module/61271) for pioneering it.
- [Cross-compiling to ARM64 in GitHub Actions](https://thewagner.net/blog/2023/11/20/building-nix-packages-for-the-raspberry-pi-with-github-actions)
