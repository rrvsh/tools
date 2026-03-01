# 2026-03-01 - folder-structure-use-cases

## Task
- Compile an exhaustive user/use-case list from `nix/` and `flake.nix`.

## Work done
- Read `flake.nix`, `nix/imports.nix`, `nix/systems.nix`.
- Read host configs in `nix/configs/`.
- Read output constructors in `nix/outputs/`.
- Reused prior module-level inventory to map use-cases across `nix/modules/`.

## Reasoning notes
- Used actor-based modeling (`<user>: <uses>`) to support future folder IA decisions.
- Kept inference constrained to observed declarations and explicit wiring patterns.

## Findings summary
- Primary actors include end user (Rafiq), host operator, Nix maintainer, CI/dev user, and contributor.
- Use-cases split naturally into identity, host assembly, app/CLI UX, desktop stack, security/secrets, package/build outputs, and policy.

## Potential follow-up
- Convert actor/use-case list into bounded contexts and naming rules for directory redesign.

## 2026-03-01 update (persona/use-case drafting research)

### New task
- Research best-practice frameworks for enumerating and analyzing possible users of a software/codebase (ICP-adjacent), then re-scan this repo and produce a concise first draft that separates use cases by user type.

### External research performed
- Reviewed audience and role framing in Google Technical Writing guidance (`developers.google.com/tech-writing/one/audience`): identify audience roles first, then knowledge proximity, then task/learning goals.
- Reviewed user-needs framing in GOV.UK Service Manual (`gov.uk/service-manual/user-research/start-by-learning-user-needs`): write user needs as need + outcome, validate with evidence, include both direct users and support/operational users.
- Reviewed persona methodology in NN/g and IxDF (`nngroup.com/articles/persona/`, `interaction-design.org/literature/topics/personas`): personas must be research-backed, focused on goals/behaviors, and limited in number to preserve decision clarity.
- Reviewed use-case framing in Martin Fowler and use-case references (`martinfowler.com/bliki/UseCase.html`, `en.wikipedia.org/wiki/Use_case`): express interactions as actor-to-system goal scenarios and keep textual use cases clear and short.
- Reviewed ICP vs buyer/user persona distinction in HubSpot and Miro (`blog.hubspot.com/...ideal-customer-profiles-and-buyer-personas...`, `miro.com/persona/ideal-customer-profile-vs-buyer-persona/`): organization-level fit (ICP) and individual role behavior (persona) should be separated.

### Practical synthesis used for draft
- Use role/persona-first segmentation.
- For each role, capture jobs/use cases as actor-goal outcomes (not implementation detail).
- Distinguish external product users from internal operators/maintainers and automation agents.
- Keep output plain, concise, and scannable in a single paragraph separated by user type.

### Repo re-scan highlights used for mapping
- Product/runtime surface: Rust site app (`rs/site`) serving markdown content from `SITE_CONTENT_DIR`, static assets, index/article routes.
- Delivery/operations: GitHub workflows for checks, image build/push to GHCR, and ECS force-redeploy; OpenTofu config for AWS ALB/ECS/ACM and GitHub OIDC role.
- Dev workflow: `Justfile` for setup, format/lint/test/check loops, docker run path, and host rebuild command.
- Security/secrets: SOPS policy and secret docs (`.sops.yaml`, `sops/README.md`).
- Personal tooling/config: Neovim setup and note-taking helper script(s), plus automation/agent skill files.

### Output intent
- Deliver one plain-English paragraph that enumerates users and their associated use cases, separated by user type.
