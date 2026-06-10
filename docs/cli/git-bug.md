git-bug
=======

rel: 8f34a17

`git-bug` is used for issue tracking. The remote used is `origin` (git@github.com:rrvsh/tools).

Aliases:
- `gu`: runs `git push` and `git-bug push`.
- `gy`: runs `git pull` and `git-bug pull`.

A custom Starship module diffs `.git/refs/bugs/` against `.git/refs/remotes/origin/bugs/` and displays an 🐛 emoji when they are not in sync.

The `ssh-add` user service is a dependency, because git-bug requires the ssh-agent to have the private key saved and can't use the private key file as a fallback like git.

There was a bug in the nixpkgs derivation that resulted in fish shell completions being broken - fixed in [this PR](https://github.com/NixOS/nixpkgs/pull/529885).
