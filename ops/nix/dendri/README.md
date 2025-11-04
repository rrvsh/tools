# dendri

this should be a flake-parts module that lets you define your users and nodes in a higher level than nixos.

## folder structure

`a/b/c/d` -> `options.flake.a.b.c.d`

## architecture

each module in a subfolder should result in changes to the relevant `config.flake.modules.<type>.leaf` lower-level module.

each module in this folder should result in generated packages or configuration.

## what this is

a sort of exploration of the dendritic method. i like the dendritic method for how it turns writing a nix flake into an act of letting the system grow organically by writing a custom flake-parts module for every problem you encounter. i pay homage to this by adding a cheeky requirement to the dendritic method rules, that i think is thematically very appropriate for real-life dendritic systems - the flake must be able to self-replicate. run `nix flake init --template github:rrvsh/cathedral#pkg_shell` to see it :)

the manifest declares all nodes, for now only nixos, and the manifest utilities will parse this "request", and automatically pick and choose modules that when put together, makes these nixosConfigurations. however, the beauty of using flake-parts is the abstraction layer of being able to have **separate** nodes have modules or options set that are dependent on **each other**, which allows us to do things like:

    - declare: this manifest provides a reverse proxy.
    - specify: this reverse proxy will run from machine a.
    - declare: machine b needs a reverse proxy to make a webapp public.

and then, the configurations will include all that is needed to make that happen.

the end state of this is essentially to provide the backend to easily automating writing/generating nix code. the syntax of the manifest options are deliberately simple, as the main issue of generating nixos configurations now are, to me, the complexity of "merging" nixos modules. so, we kind of "merge" those modules first before we present a simpler set of options to the user.
