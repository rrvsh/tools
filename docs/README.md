## RULES

- every file must be ATOMIC -> HARD REQUIREMENT! includes all types of files
- lists (of all kinds) should be sorted

## dev setup

with `direnv`, run `direnv allow` and all dependencies will be in your shell. otherwise, install nix and run `nix develop` after cloning the repository.

warning: the logic is in an unfinished state. you cannot yet import any flake-parts module i have written here and put it into your own config, or for most of my modules as a general rule (too much dependence on each other). feel free to steal any of the logic for yourself though :)

run:

- `bacon rebuild` to watch for changes and rebuild nix darwin
- `just nice` to format nix files and lint (format gha is slow)
- `just check` to format, lint, and run tests

## acknowledgements

- [ornicar](https://github.com/ornicar/dotfiles), for being my inspiration to start using Nix, open source, and being a full fledged software engineer
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) for teaching me how to use NixOS, flakes, and home-manager: the best damn tutorial on the internet I've seen yet
- [NotAShelf](https://github.com/notashelf/nyx) for introducing me to the idea of monorepos and custom logic (read: over-engineering) for Nix flakes
- [drupol/infra](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/) for introducing the dendritic pattern to me, and [mightyiam](https://discourse.nixos.org/t/pattern-every-file-is-a-flake-parts-module/61271) for pioneering it.
