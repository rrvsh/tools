the flake uses import-tree to essentially import every file recursively in `nix/` excluding any files or directories that are in a directory beginning with an underscore such as `_packages`.

`veil` is a raspberry pi 4b that will serve as a reverse proxy to the network and other services. it currently hosts my website http://rrv.sh

user passwords are stored in the git repo using sops-nix for encryption and mounting
