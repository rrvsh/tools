# AGENTS.md

## Scope

Terraform/OpenTofu infrastructure for AWS resources used by this repository.

## File Index

- `main.tf`: provider/backend and shared Terraform setup.
- `vpc.tf`: network primitives.
- `security_groups.tf`: security group definitions.
- `site.tf`: application/service infrastructure.
- `state_bucket.tf`: state storage infrastructure.
- `github_actions.tf`: CI identity/permissions plumbing.
- `.terraform.lock.hcl`: provider lockfile.

## Rules

- Keep resources organized by concern across files.
- Preserve backend/provider consistency.
- Treat infra edits as high-impact and verify workflow compatibility.
