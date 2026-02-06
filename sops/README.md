# Secrets

## Required

- `rafiq/password`: Hashed password with `mkpasswd -s` for `users.users.rafiq.hashedPasswordFile`.
- `rafiq/tailscale-authkey`: Tailscale auth key for auto-enrolling nodes.

## Editing

1. Generate/refresh the age key (see `docs/runbook.md`).
2. Edit secrets: `sops sops/rafiq.yaml`
3. Update values and save; SOPS will re-encrypt the file.
