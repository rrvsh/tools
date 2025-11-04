# dendri

this should be a flake-parts module that lets you define your users and nodes in a higher level than nixos.

## folder structure

`a/b/c/d` -> `options.flake.a.b.c.d`

## architecture

each module in a subfolder should result in changes to the relevant `config.flake.modules.<type>.leaf` lower-level module.

each module in this folder should result in generated packages or configuration.
