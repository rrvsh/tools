## current state

- externals
    - nginx: proxies complete, todo is static sites and deeper config
- internals
    - added ssh, tailscale
- nodes
    - device: disko configurations
    - type: facter and disko
    - nixos: default nixos modules and construction
- secrets
    - sops: done basically? figure out api
- users
    - users: provides user info
    - admin: provides admin user for e.g. sops

TODO:
    - figure out how to get one vm running thats it


## what this is

a sort of exploration of the dendritic method. i like the dendritic method for how it turns writing a nix flake into an act of letting the system grow organically by writing a custom flake-parts module for every problem you encounter. i pay homage to this by adding a cheeky requirement to the dendritic method rules, that i think is thematically very appropriate for real-life dendritic systems - the flake must be able to self-replicate. run `nix flake init --template github:rrvsh/cathedral#pkg_shell` to see it :)

the manifest declares all nodes, for now only nixos, and the manifest utilities will parse this "request", and automatically pick and choose modules that when put together, makes these nixosConfigurations. however, the beauty of using flake-parts is the abstraction layer of being able to have **separate** nodes have modules or options set that are dependent on **each other**, which allows us to do things like:

    - declare: this manifest provides a reverse proxy.
    - specify: this reverse proxy will run from machine a.
    - declare: machine b needs a reverse proxy to make a webapp public.

and then, the configurations will include all that is needed to make that happen.

the end state of this is essentially to provide the backend to easily automating writing/generating nix code. the syntax of the manifest options are deliberately simple, as the main issue of generating nixos configurations now are, to me, the complexity of "merging" nixos modules. so, we kind of "merge" those modules first before we present a simpler set of options to the user.

### RULES

- every file must be ATOMIC -> HARD REQUIREMENT! includes all types of files
- lists should be sorted if possible

## dev setup

with `direnv`, run `direnv allow` and all dependencies will be in your shell. otherwise, install nix and run `nix develop` after cloning the repository.

warning: the logic is in an unfinished state. you cannot yet import any flake-parts module i have written here and put it into your own config, or for most of my modules as a general rule (too much dependence on each other). feel free to steal any of the logic for yourself though :)

run:

- `just nice` to format and lint
- `just check` to test

## acknowledgements

- [ornicar](https://github.com/ornicar/dotfiles), for being my inspiration to start using Nix, open source, and being a full fledged software engineer
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) for teaching me how to use NixOS, flakes, and home-manager: the best damn tutorial on the internet I've seen yet
- [NotAShelf](https://github.com/notashelf/nyx) for introducing me to the idea of monorepos and custom logic (read: over-engineering) for Nix flakes
- [drupol/infra](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/) for introducing the dendritic pattern to me, and [mightyiam](https://discourse.nixos.org/t/pattern-every-file-is-a-flake-parts-module/61271) for pioneering it.
