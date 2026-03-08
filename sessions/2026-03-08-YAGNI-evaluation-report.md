# YAGNI Evaluation Report for tools Repository

**Date:** 2026-03-08  
**Scope:** Full repository analysis  
**Objective:** Identify unnecessary complexity, premature abstractions, and speculative features

---

## Executive Summary

This repository exhibits **significant YAGNI violations**, particularly in:
1. **Agent skill system** - Over-engineered documentation framework
2. **CI/CD infrastructure** - Premature optimization for scale not yet needed
3. **Nix module architecture** - Excessive granularity and indirection
4. **Rust web application** - Unnecessary MVC abstraction for a simple blog

---

## Critical YAGNI Violations (High Impact)

### 1. Agent Skills Framework (`.agents/skills/`)

**Files:** All files in `.agents/skills/*/SKILL.md`

**Violation:** Complete framework of 7 skill files documenting how to use tools that are already self-evident:
- `web-search/SKILL.md` (8 lines) - Documents `ddgr` command
- `git/SKILL.md` (2 lines) - Documents a single git flag
- `just/SKILL.md` (7 lines) - Documents Justfile commands that are already documented in the Justfile
- `nix/SKILL.md` (94 lines) - Nix documentation largely duplicating official docs
- `session-management/SKILL.md` (98 lines) - Complex process for managing session files
- `opencode-docs-index/SKILL.md` (44 lines) - Index of OpenCode documentation URLs
- `tmux-e2e-cli-agent/SKILL.md` (22 lines) - tmux patterns for testing

**Why this is YAGNI:**
- These "skills" duplicate information from `--help`, man pages, and official docs
- No evidence that an agent has ever needed to reference these
- The session management skill describes a complex workflow for extracting learnings that has no proven value
- `opencode-docs-index` is literally a mirror of public documentation URLs

**Recommendation:** Delete entire `.agents/skills/` directory. The information is:
1. Available via tool help/man pages
2. In OpenCode's own documentation
3. Intuitive from reading the actual code

---

### 2. Complex GitHub Actions Workflow (`.github/workflows/check.yaml`)

**File:** `.github/workflows/check.yaml` (299 lines)

**Violations:**

#### a) Excessive Change Detection Jobs (Lines 15-85)
```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      workflow: ${{ steps.workflow.outputs.any_changed }}
      gha: ${{ steps.gha.outputs.any_changed }}
      lua: ${{ steps.lua.outputs.any_changed }}
      nix: ${{ steps.nix.outputs.any_changed }}
      rust: ${{ steps.rust.outputs.any_changed }}
      flake: ${{ steps.flake.outputs.any_changed }}
```

Six separate change detection steps using `tj-actions/changed-files` for a repository with:
- 1 Rust package
- ~30 Nix files
- 0 Lua files (no lua source in repo, only nvim config)

**Why YAGNI:**
- Repository rebuilds complete in seconds; conditional jobs save negligible time
- The flake input detection (`flake` output) duplicates the `nix` output
- No evidence CI minutes are a constraint

#### b) Separate CI Shells (Lines 14-70 in `devShells.nix`)
```nix
devShells = {
  default = mkRustShell defaultInputs;
  ci-gha = mkShell ciInputs.gha;
  ci-lua = mkShell ciInputs.lua;
  ci-nix = mkShell ciInputs.nix;
  ci-rs = mkRustShell ciInputs.rs;
};
```

Five separate dev shells when a single shell with all tools would suffice.

**Recommendation:** 
- Remove change detection entirely - run all checks unconditionally
- Consolidate to 1-2 dev shells (default + minimal)
- Estimated savings: ~150 lines of YAML, simpler mental model

---

### 3. Over-Engineered Rust Web Application (`rs/site/`)

**File:** `rs/site/src/app/models/document.rs` (119 lines)

**Violation:** `ignore::Walk` dependency for simple file reading

```rust
pub fn load_documents_from_dir<P: AsRef<Path>>(path: P) -> Vec<Document> {
    let mut documents = Walk::new(path)  // <-- Using ignore crate
        .filter_map(std::result::Result::ok)
        .filter_map(|entry| Document::from_path(entry.path()))
        .collect::<Vec<Document>>();
    documents.sort_by(|left, right| right.date.cmp(&left.date));
    documents
}
```

**Why YAGNI:**
- The `ignore` crate (13 dependencies) is used solely to traverse a directory
- Standard library `std::fs::read_dir()` would work perfectly
- No `.gitignore` handling is actually needed (content is from a separate repo)
- The content directory structure is flat/known

**Additional violation in same file (Lines 54-118):** 
Excessive unit tests for simple parsing:
- 4 test functions testing trivial parsing logic
- Tests like `document_failure_not_markdown` test file extension checking (std lib behavior)
- Test setup uses `tempfile` crate just to write test fixtures

**Recommendation:**
- Replace `ignore::Walk` with `std::fs::read_dir()`
- Remove `ignore` and `tempfile` dependencies
- Reduce tests to 1-2 integration tests, delete the rest
- Estimated savings: 2 crates, ~80 lines of test code

---

### 4. Complex URL Date Parsing in Article Controller

**File:** `rs/site/src/app/controllers/article.rs` (40 lines)

**Violation:** Complex date reconstruction from URL path components

```rust
pub async fn get(
    Path((year, month, day, slug)): Path<(i32, u32, u32, String)>,
    State(state): State<Arc<AppState>>,
) -> Result<Response, StatusCode> {
    let requested_date = NaiveDate::from_ymd_opt(year, month, day).ok_or(StatusCode::NOT_FOUND)?;
    let document = state
        .articles_by_key
        .get(&(year, month, day, slug))
        .ok_or(StatusCode::NOT_FOUND)?;
```

**Why YAGNI:**
- The date in URL is purely cosmetic - the lookup uses a composite key anyway
- The `articles_by_key` HashMap already contains the date from frontmatter
- The date validation is redundant - if the key exists, the date is valid
- URL could just be `/article/{slug}` - simpler, cleaner

**Recommendation:**
- Simplify URL to `/article/{slug}` 
- Remove date from URL entirely
- Estimated savings: ~15 lines, simpler routing

---

## Moderate YAGNI Violations (Medium Impact)

### 5. Excessive Nix Module Granularity

**Files:** `nix/modules/cli/*.nix`, `nix/modules/desktop/*.nix`

**Violation:** 24+ separate module files, many <20 lines each:

```nix
# nix/modules/cli/utils-ddgr.nix (likely <15 lines)
# nix/modules/cli/utils-zoxide.nix (likely <15 lines)
# nix/modules/desktop/gaming-steam.nix (likely <20 lines)
```

**Why YAGNI:**
- Each module defines ~1-2 package installations
- High file count with low content density
- The "one file = one responsibility" principle taken to extreme
- No module is imported conditionally based on complex logic - they're just grouped in profiles

**Recommendation:**
- Group related modules: `cli-tools.nix`, `desktop-base.nix`, `desktop-gaming.nix`
- Estimated consolidation: 24 files → 6-8 files
- Trade-off: Slightly less "pure" separation, but much easier to navigate

---

### 6. Session Management System

**Files:** `sessions/` directory, `sessions/archived/`, `sessions/raw/`

**Violation:** Complex session note system with:
- Raw session exports
- Manual processing workflow
- Archiving system
- Skill extraction process (documented in SKILL.md)

**Evidence:** 12 unprocessed session files from March 2025-2026, archived folder exists

**Why YAGNI:**
- No evidence these session notes are ever referenced
- The skill extraction process (spawn subagents, extract learnings, update skills) is elaborate
- Skills file themselves are YAGNI (see #1)
- Standard git commit messages + code comments suffice

**Recommendation:**
- Delete `sessions/` directory entirely
- Use git history for reference
- Estimated savings: ~30KB of markdown, simplified workflow

---

### 7. Docker/OCI Image Abstraction

**File:** `nix/outputs/packages.nix` (Lines 11-30)

**Violation:** Complex layered image build for a single binary

```nix
packages.site-image = pkgs.dockerTools.buildLayeredImage {
  name = "site";
  tag = "latest";
  contents = [
    self'.packages.site-bin
    pkgs.dockerTools.binSh
  ];
  config = {
    Env = [
      "SITE_CONTENT_DIR=${inputs.site-content}"
      "STATIC_DIR=${config.flake.paths.root + /rs/site/static}"
    ];
    Entrypoint = [ "/bin/sh" "-c" ];
    Cmd = [ "/bin/site" ];
  };
};
```

**Why YAGNI:**
- The site is a single static binary with no runtime dependencies
- Could use `pkgs.dockerTools.buildImage` (simpler) or even just `docker build` with a Dockerfile
- The layered approach optimizes for cache hits that don't matter for this use case
- Multi-arch builds in CI add complexity for minimal benefit

**Recommendation:**
- Use simpler image build
- Or eliminate Docker entirely - deploy binary directly to server
- Estimated savings: ~15 lines, simpler deployment

---

### 8. Empty/Placeholder Module Structure

**File:** `rs/site/src/app/controllers/mod.rs` (20 lines)

**Violation:** Unnecessary module nesting

```rust
mod article;
mod index;

use crate::app::state::AppState;
use axum::routing::get;
use std::path::PathBuf;
use std::sync::Arc;
use tower_http::services::ServeDir;

pub fn build_router(state: Arc<AppState>, content_dir: &str, static_dir: &str) -> axum::Router {
    // ... 13 lines
}
```

**Why YAGNI:**
- The entire app has exactly 2 routes (index + article)
- Could be a single `main.rs` file (~100 lines)
- MVC structure (models/views/controllers) is overkill for 2 endpoints

**Similar violations:**
- `rs/site/src/app/models/mod.rs` - 1 line re-export
- `rs/site/src/app/views/mod.rs` - View structs that could be in templates

**Recommendation:**
- Flatten to single file or minimal structure
- Estimated savings: 6 source files → 1-2 files

---

## Minor YAGNI Violations (Low Impact)

### 9. Unused Profile Files

**File:** `nix/profiles/alpha.nix` (18 lines)

**Violation:** Profile with minimal configuration

```nix
{
  config.flake.hosts.darwin.alpha.modules = [
    {
      system = {
        activationScripts.extraActivation.text = ''
          echo >&2 "configuring power management..."
          sudo pmset -a disablesleep 1
          sudo pmset -a displaysleep 0
        '';
        defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
        keyboard = {
          enableKeyMapping = true;
          remapCapsLockToEscape = true;
        };
      };
    }
  ];
}
```

**Why YAGNI:**
- Single-host configuration could be inline in the host config
- The separate file adds indirection for 5 settings
- No other profiles exist that share this

**Recommendation:**
- Inline into `nix/outputs/darwinConfigurations.nix`
- Estimated savings: 1 file, reduced cognitive load

---

### 10. Flake Input Optimization Complexity

**File:** `flake.nix` (Lines 6-72)

**Violation:** 24 flake inputs with extensive `follows` chains

```nix
inputs = {
  flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  flake-parts.url = "github:hercules-ci/flake-parts";
  home-manager.inputs.nixpkgs.follows = "nixpkgs";
  # ... 20 more inputs
};
```

**Why YAGNI:**
- The `follows` chains attempt to deduplicate nixpkgs instances
- For a personal config, the closure size savings are negligible
- Adds complexity to reasoning about which nixpkgs version each input uses
- Several inputs are likely unused (neovim-nightly-overlay when using nvf?)

**Potential unused inputs to investigate:**
- `neovim-nightly-overlay` (conflicts with `nvf` input?)
- `fff-nvim` (may not be actively used)
- `epub-nvim` (specialized use case)

---

### 11. Document Date Formatting Over-Engineering

**File:** `rs/site/src/app/views/mod.rs` (Lines 47-65)

**Violation:** Complex ordinal suffix logic for dates

```rust
pub fn format_article_date(date: NaiveDate) -> String {
    let day = date.day();
    let suffix = match day % 100 {
        11..=13 => "th",
        _ => match day % 10 {
            1 => "st",
            2 => "nd",
            3 => "rd",
            _ => "th",
        },
    };

    format!(
        "{}, the {day}{suffix} of {} {}",
        date.format("%A"),
        date.format("%B"),
        date.year()
    )
}
```

**Why YAGNI:**
- Could use simple `date.format("%B %d, %Y")` ("March 08, 2026")
- The ordinal suffix ("8th") adds 18 lines for stylistic preference
- No user has requested this format

**Recommendation:**
- Use standard date format
- Estimated savings: ~18 lines

---

## Architectural Concerns

### 12. Import-Tree Pattern Overuse

**Files:** `nix/imports.nix`, `flake.nix`

**Violation:** Using `import-tree` library for simple module imports

```nix
# flake.nix line 5
flake-parts.lib.mkFlake { inherit inputs; } ((import-tree ./nix) // { ... });

# nix/imports.nix
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
}
```

**Why YAGNI:**
- `import-tree` adds a dependency to avoid explicit imports
- Standard `imports = [ ./path/to/file.nix ];` is clearer
- The "dendritic pattern" mentioned in README is clever but unnecessary for ~50 modules
- Makes it harder to trace where modules come from

**Trade-off:** This is a preference, but explicit imports are more maintainable

---

### 13. Elaborate Lint Configuration

**File:** `rs/site/Cargo.toml` (Lines 24-32)

**Violation:** Extremely strict clippy configuration

```toml
[lints.clippy]
correctness = "deny"
suspicious = "deny"
complexity = "deny"
perf = "deny"
style = "deny"
pedantic = "deny"
cargo = "deny"
nursery = "deny"
```

**Why YAGNI:**
- All lint categories denied, including `pedantic` and `nursery`
- For a personal project, this creates unnecessary friction
- May encourage workarounds or `#[allow()]` attributes
- `cargo` lints are for published crates (this has `version = "0.1.0-alpha"`)

**Recommendation:**
- Use defaults + explicit enables for important lints
- Or use `warn` instead of `deny` for pedantic/nursery

---

## Summary Table

| Category | Count | Lines | Impact |
|----------|-------|-------|--------|
| **Critical** | 4 | ~500 | High complexity reduction |
| **Moderate** | 4 | ~200 | Medium simplification |
| **Minor** | 5 | ~100 | Polish/cleanup |
| **Total** | 13 | ~800 | Significant simplification |

## Recommendations Priority

### Immediate Actions (High Value, Low Effort)
1. **Delete `.agents/skills/`** - 7 files, no functionality loss
2. **Simplify Rust web app** - Flatten MVC, remove `ignore` crate
3. **Consolidate CI** - Remove change detection, single dev shell

### Short-term (Medium Value)
4. **Consolidate Nix modules** - Group related modules
5. **Simplify session management** - Use git history
6. **Flatten Rust structure** - Single file or minimal modules

### Consideration (Trade-offs Exist)
7. **Reconsider import-tree** - Explicit imports vs. convenience
8. **Review flake inputs** - Audit for unused dependencies

## Conclusion

This repository exhibits classic "infrastructure as hobby" patterns - sophisticated, well-engineered solutions to problems that don't yet exist. The YAGNI principle is violated most severely in:

1. **Documentation systems** (skills, sessions) that create work without delivering value
2. **CI/CD optimizations** for scale not yet achieved
3. **Architectural patterns** (MVC, granular modules) that add indirection without necessity

The repository would benefit significantly from aggressive simplification, focusing on:
- **Working code over perfect structure**
- **Explicit over clever**
- **Single source of truth** (no documentation duplication)

Estimated total reduction: **~800 lines of code/configuration** and significantly improved maintainability.
