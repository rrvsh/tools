# Terraform/OpenTofu Guidelines

## Checks

```bash
just format-tf    # Format terraform files
```

## Code Style

Formatting: Uses `tofu fmt tf` (NOT `tofu -chdir=tf fmt` - the -chdir flag is not supported).

State: Remote state in AWS S3 (see `tf/state_bucket.tf`).

## Versions

- OpenTofu: ~> 1.11
- AWS provider: ~> 6.0

## Key Resources

- ECS Fargate cluster for site container
- ALB with ACM certificate for HTTPS
- GHA OIDC provider for AWS auth via `aws_iam_role.github_actions`
