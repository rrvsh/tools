# tools

these are the tools i currently use

## working with the repo

### setup
- run `gh auth login` to authenticate (for zizmor)

### day to day
- `just nice` formats and auto-fixes lints
- `just check` runs the same check run in CI for formatting, linting, and testing
- `just rb` rebuilds the local Darwin system configuration after running `nice`, then `check`.
    *- planned: allow specifying remote to rebuild, add support for not-Darwins*

### github automation
- daily controller workflow: `.github/workflows/github-automation.yaml`
- proactive scan worker workflow: `.github/workflows/opencode-proactive-scan.yaml`
- configuration: `automation/repos.json`
- documentation: `docs/github-automation.md`

## acknowledgements

- [ornicar](https://github.com/ornicar/dotfiles), for being my inspiration to start using Nix, open source, and being a full fledged software engineer
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) for teaching me how to use NixOS, flakes, and home-manager: the best damn tutorial on the internet I've seen yet
- [NotAShelf](https://github.com/notashelf/nyx) for introducing me to the idea of monorepos and custom logic (read: over-engineering) for Nix flakes
- [drupol/infra](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/) for introducing the dendritic pattern to me, and [mightyiam](https://discourse.nixos.org/t/pattern-every-file-is-a-flake-parts-module/61271) for pioneering it.
- [Cross-compiling to ARM64 in GitHub Actions](https://thewagner.net/blog/2023/11/20/building-nix-packages-for-the-raspberry-pi-with-github-actions)
