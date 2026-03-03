## Task

Refactor `tf/` to extract the full site stack into a reusable `modules/site` OpenTofu module, then wire root config to consume it.

## Plan

- Capture baseline plan artifacts (`before.plan`, `before.json`) using OpenTofu.
- Create module `tf/modules/site` with site resources and explicit inputs/outputs.
- Refactor root files (`data.tf`, module call, IAM reference updates, outputs centralization).
- Add `moved` blocks for state-safe address migration.
- Capture `after.plan`, `after.json` and verify no functional diff.

## Notes

- Initial `tofu init` with backend access failed locally due missing AWS credentials.

## Work Completed

- Added `tf/modules/site` with all former site stack resources:
  - ACM cert + validation
  - Public ALB + listeners + target group
  - ALB/public SG and service SG/rules
  - ECS cluster/task definition/service
- Added root module call in `tf/site_module.tf`.
- Added shared data sources in `tf/data.tf`.
- Updated GitHub Actions IAM policy to reference `module.site.service_arn`.
- Centralized root outputs in `tf/outputs.tf`.
- Added state-safe refactor mappings in `tf/moved.tf`.
- Removed replaced root files: `tf/site.tf`, `tf/security_groups.tf`, `tf/vpc.tf`.
- Added `scripts/tofu-plan-head.sh` to run a plan from clean git ref/worktree and emit `head.plan` + `head.json` for semantic plan diff workflows.

## Verification

- `tofu fmt -recursive`: pass.
- `tofu validate`: pass.
- Ran `scripts/tofu-plan-head.sh --ref HEAD --tf-dir tf --out-dir /tmp/tf-head-plan`: pass (`No changes`).
- Ran working-tree plan in `tf/` and exported JSON to `/tmp/tf-workdir-plan/working.json`.
- JSON comparison (managed resources):
  - HEAD: `managed=21 actionable=0 moved=0`
  - Working tree: `managed=21 actionable=0 moved=16`
- Output changes: `0` for both plans.
- Result: no functional infrastructure diff; only resource-address moves into `module.site`.
