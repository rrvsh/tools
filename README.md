# tools

these are the tools i currently use

## working with the repo

- Just commands
    - `just nice` formats and auto-fixes lints
    - `just check` runs the same check run in CI for formatting, linting, and testing

## RULES
- prime must only contain tools currently in use
- branches are to add new tools and must be in use for at least a week before being merged
- lists (of all kinds) should be sorted
- READMES everywhere with more RULES
- files should include comments where appropriate (the appropriateness scales with how shallowly nested it is)

## acknowledgements

- [ornicar](https://github.com/ornicar/dotfiles), for being my inspiration to start using Nix, open source, and being a full fledged software engineer
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) for teaching me how to use NixOS, flakes, and home-manager: the best damn tutorial on the internet I've seen yet
- [NotAShelf](https://github.com/notashelf/nyx) for introducing me to the idea of monorepos and custom logic (read: over-engineering) for Nix flakes
- [drupol/infra](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/) for introducing the dendritic pattern to me, and [mightyiam](https://discourse.nixos.org/t/pattern-every-file-is-a-flake-parts-module/61271) for pioneering it.
