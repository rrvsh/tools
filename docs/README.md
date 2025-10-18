the flake uses import-tree to essentially import every file recursively in `nix/` excluding any files or directories that are in a directory beginning with an underscore such as `_packages`.

machines are connected using tailscale with the auth key being stored using sops

`veil` is a raspberry pi 4b that will serve as a reverse proxy to the network and other services. it currently hosts my website http://rrv.sh

user passwords are stored in the git repo using sops-nix for encryption and mounting

ssl is handled by lets encrypt via acme using DNS-01 validation thru cloudflare

linting, formatting, and other checks are handled by various tools depending on the language, see Justfile or CI for more

Each PR must include changes to `docs/`

The configuration option `flake.paths` contains relative paths to folders in the repository, such as `flake.paths.root` pointing to the repository root
