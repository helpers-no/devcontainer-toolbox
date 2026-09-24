# Feature: dev-template-ai.sh — AI Workflow Template Installer

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Completed**: 2026-03-30

**Goal**: Create `dev-template-ai.sh` that installs AI workflow templates from `helpers-no/dev-templates` into any project, following the same UX as `dev-template.sh`.

**Last Updated**: 2026-03-30

**Investigation**: [INVESTIGATE-ai-workflow-installer.md](../completed/INVESTIGATE-ai-workflow-installer.md) (to be moved to completed)

---

## Overview

`dev-template-ai.sh` is a parallel script to `dev-template.sh` v1.6.0 that installs AI workflow templates instead of app templates. It downloads from the same `helpers-no/dev-templates` repo but scans `ai-templates/` instead of `templates/`.

**Key differences from `dev-template.sh`:**
- Scans `ai-templates/` instead of `templates/`
- Copies `template/` subdirectory contents (not template root)
- No `manifests/deployment.yaml` validation
- No `.gitignore` merge, no `.github/workflows` copy
- Only `{{REPO_NAME}}` placeholder in `.md` files (not YAML)
- Special CLAUDE.md conflict handling
- Safe re-run: overwrite template-owned docs, never overwrite user plans
- Renames `project-TEMPLATE.md` to `project-{repo-name}.md`

**First template available:** `plan-based-workflow` — structured AI development with plans, phases, and validation.

---

## Phase 1: Create script skeleton with metadata and prerequisites — DONE

### Tasks

- [x] 1.1 Create `.devcontainer/manage/dev-template-ai.sh` with script metadata:
  - `SCRIPT_ID="dev-template-ai"`
  - `SCRIPT_NAME="AI Templates"`
  - `SCRIPT_DESCRIPTION="Install AI workflow templates into your project"`
  - `SCRIPT_CATEGORY="SYSTEM_COMMANDS"`
  - `SCRIPT_VERSION="1.0.0"`
- [x] 1.2 Add path resolution block (same pattern as `dev-template.sh`):
  - `CALLER_DIR`, `SCRIPT_DIR`, `DEVCONTAINER_DIR`, `ADDITIONS_DIR`
- [x] 1.3 Source `git-identity.sh` from `$ADDITIONS_DIR/lib/`
- [x] 1.4 Add `check_prerequisites()` — require `dialog` and `unzip`
- [x] 1.5 Add `detect_and_validate_repo_info()` — only needs `GIT_REPO` (not `GIT_ORG`)
- [x] 1.6 Add `display_intro()` banner
- [x] 1.7 Make script executable

### Validation

`dev-template-ai.sh --help` works, prerequisites check runs.

---

## Phase 2: Template download and scanning — DONE

### Tasks

- [x] 2.1 Add `download_templates()` — download `helpers-no/dev-templates` zip (same as `dev-template.sh`)
- [x] 2.2 Add `read_template_info()` — read `TEMPLATE_INFO` from each subfolder (reuse pattern)
- [x] 2.3 Add `scan_templates()` — scan `ai-templates/*/` directories instead of `templates/*/`
  - Build parallel arrays: `TEMPLATE_DIRS`, `TEMPLATE_NAMES`, `TEMPLATE_DESCRIPTIONS`, `TEMPLATE_CATEGORIES`, `TEMPLATE_PURPOSES`
- [x] 2.4 Add `verify_template()` — check `template/` subdirectory exists (no manifests check)

### Validation

Script downloads repo, finds `plan-based-workflow` template, reads its TEMPLATE_INFO.

---

## Phase 3: Dialog menu and template selection — DONE

### Tasks

- [x] 3.1 Add `show_template_menu()` — dialog menu grouped by category (reuse pattern from `dev-template.sh`)
- [x] 3.2 Add `show_template_details()` — show name, category, description, purpose; confirm selection
- [x] 3.3 Add `select_template()` — loop until user confirms or cancels
- [x] 3.4 Support direct selection via command-line argument: `dev-template-ai.sh plan-based-workflow`

### Validation

User can browse templates, see details, and confirm selection.

---

## Phase 4: File copy with safe re-run logic — DONE

### Tasks

- [x] 4.1 Add `copy_template_files()` — copy `template/` contents to `$CALLER_DIR/` preserving directory structure, with rules:
  - Always overwrite template-owned docs: `README.md`, `WORKFLOW.md`, `PLANS.md`, `DEVCONTAINER.md`, `GIT.md`, `TALK.md`, `project-TEMPLATE.md`
    - **Note (2026-09-24):** `TALK.md` is retired. It described a file-based agent bus that the fleet replaced with GitHub issues, and `helpers-no/dev-templates` no longer ships it. Do not reintroduce it.
  - Never overwrite user-renamed `project-*.md` files (anything other than `project-TEMPLATE.md`)
  - Never overwrite anything in `plans/` subdirectories (backlog/, active/, completed/) — user's work
  - Create `plans/` directories with `.gitkeep` only if they don't exist
- [x] 4.2 Add `handle_claude_md()` — CLAUDE.md conflict handling:
  - If `$CALLER_DIR/CLAUDE.md` exists: delete the copied one, keep `docs/ai-developer/CLAUDE-template.md`, print merge instructions
  - If no existing CLAUDE.md: keep the copied one, delete `CLAUDE-template.md`
- [x] 4.3 Add `rename_project_template()` — rename `project-TEMPLATE.md` to `project-{GIT_REPO}.md` if it was copied

### Validation

User confirms: files copied correctly, CLAUDE.md handling works both ways, project file renamed.

---

## Phase 5: Placeholder replacement and cleanup — DONE

### Tasks

- [x] 5.1 Add `replace_placeholders()` — replace `{{REPO_NAME}}` with `$GIT_REPO` in `.md` files
- [x] 5.2 Add `process_template_files()` — process all `.md` files under `$CALLER_DIR/docs/ai-developer/` and `$CALLER_DIR/CLAUDE.md`
- [x] 5.3 Add `cleanup_and_complete()` — remove temp dir, show completion message with next steps
- [x] 5.4 Wire up the main execution flow:
  1. Parse args
  2. `check_prerequisites`
  3. `detect_and_validate_repo_info`
  4. `display_intro`
  5. `download_templates`
  6. `scan_templates`
  7. `select_template`
  8. `verify_template`
  9. `copy_template_files`
  10. `handle_claude_md`
  11. `rename_project_template`
  12. `process_template_files`
  13. `cleanup_and_complete`

### Validation

Full end-to-end run: template installed, placeholders replaced, CLAUDE.md handled, cleanup done.

---

## Phase 6: Add --help flag — DONE

### Tasks

- [x] 6.1 Add `--help` / `-h` argument parsing to `dev-template-ai.sh` — checked BEFORE prerequisites and git detection
- [x] 6.2 Add `--help` / `-h` argument parsing to `dev-template.sh` — same pattern
- [x] 6.3 Help text for `dev-template-ai.sh`:
  ```
  🤖 AI Workflow Template Installer v1.0.0

  Usage: dev-template-ai.sh [template-name]

    dev-template-ai.sh                      Show interactive menu
    dev-template-ai.sh plan-based-workflow   Install specific template
    dev-template-ai.sh --help               Show this help

  Installs AI workflow templates from helpers-no/dev-templates into your
  project. Templates include CLAUDE.md, plan structure, and workflow docs.

  How it works:
    Uses git sparse-checkout to download only the ai-templates/ folder
    from helpers-no/dev-templates to a temp directory. The selected
    template is then copied into your project. Temp files are cleaned
    up automatically. No git authentication required (public repo).

  Source: https://github.com/helpers-no/dev-templates/tree/main/ai-templates
  ```
- [x] 6.4 Help text for `dev-template.sh`:
  ```
  🛠️  Project Template Initializer v1.6.0

  Usage: dev-template.sh [template-name]

    dev-template.sh                              Show interactive menu
    dev-template.sh typescript-basic-webserver   Install specific template
    dev-template.sh --help                       Show this help

  Installs project templates from helpers-no/dev-templates into your
  project. Templates include app scaffolding, Kubernetes manifests,
  and GitHub Actions workflows.

  How it works:
    Uses git sparse-checkout to download only the templates/ folder
    from helpers-no/dev-templates to a temp directory. The selected
    template is then copied into your project with placeholder
    substitution. Temp files are cleaned up automatically.
    No git authentication required (public repo).

  Source: https://github.com/helpers-no/dev-templates/tree/main/templates
  ```

### Validation

`dev-template-ai.sh --help` and `dev-template.sh --help` both show usage info without downloading templates.

---

## Phase 7: Fix CLAUDE.md conflict detection bug — DONE

### Problem

`copy_template_files()` overwrites `CLAUDE.md` first, then `handle_claude_md()` checks if one existed — but it's too late, the original is already overwritten. The `[ -f "$caller_claude" ]` check always returns true because we just copied it.

### Tasks

- [x] 7.1 Save CLAUDE.md state and backup BEFORE `copy_template_files()`
- [x] 7.2 After `copy_template_files()`, restore backup if CLAUDE.md existed
- [x] 7.3 Update `handle_claude_md()` to use `$CLAUDE_EXISTED` flag

### Validation

Test both scenarios: with and without existing CLAUDE.md.

---

## Phase 8: Replace zip download with git sparse-checkout — DONE

### Tasks

- [x] 8.1 Update `download_template_repo()` in `lib/template-common.sh` — sparse-checkout with `--depth 1`
- [x] 8.2 Update both scripts to use `TEMPLATE_REPO_DIR` instead of `TEMPLATE_REPO_NAME`
- [x] 8.3 Removed `cd "$TEMP_DIR"` — sparse-checkout clones directly to `$TEMP_DIR/repo/`
- [x] 8.4 Replaced `unzip` with `git` in `check_template_prerequisites()`

### Validation

Both scripts download only their needed folder, not the entire repo.

---

## Phase 9: Testing — DONE

### Tasks

- [x] 9.1 Test `dev-template-ai.sh` in devcontainer with interactive dialog selection
- [x] 9.2 Test direct selection: `dev-template-ai.sh plan-based-workflow`
- [x] 9.3 Test CLAUDE.md conflict: run in project WITH existing CLAUDE.md — original preserved, CLAUDE-template.md kept
- [x] 9.4 Test CLAUDE.md no-conflict: run in project WITHOUT CLAUDE.md — installed, CLAUDE-template.md removed
- [x] 9.5 Test safe re-run: run twice, plans/ not overwritten, project-delete-test.md preserved
- [x] 9.6 Test placeholder replacement: `{{REPO_NAME}}` replaced in all `.md` files
- [x] 9.7 Test `dev-template.sh` regression — PHP template installed successfully end-to-end
- [x] 9.8 Sparse-checkout works without git auth (public repo, no gh login)
- [x] 9.9 Test invalid template name: `dev-template-ai wrong-template-name` — error handled correctly

### Validation

All tests pass. Both scripts work with sparse-checkout. No regression in dev-template.sh.

---

## Acceptance Criteria

- [x] `dev-template-ai.sh` installs AI workflow template to `docs/ai-developer/`
- [x] Downloads only `ai-templates/` folder (not full repo) via git sparse-checkout
- [x] `dev-template.sh` downloads only `templates/` folder (not full repo)
- [x] Interactive dialog menu with category grouping
- [x] Direct selection via command-line argument
- [x] `{{REPO_NAME}}` replaced in all `.md` files
- [x] CLAUDE.md conflict handling works correctly
- [x] Safe re-runs: template docs overwritten, user plans preserved
- [x] `project-TEMPLATE.md` renamed to `project-{repo-name}.md`
- [x] Prerequisites checked (dialog, git — no longer requires unzip)
- [x] Cleanup removes temp directory
- [x] Script metadata present for component scanner
- [x] Works without git authentication (public repo)
- [x] `--help` flag works for both scripts (without requiring dialog or git remote)
- [x] No regression in `dev-template.sh` functionality

---

## Files to Create/Modify

- `.devcontainer/manage/lib/template-common.sh` (new — shared library)
- `.devcontainer/manage/dev-template-ai.sh` (new)
- `.devcontainer/manage/dev-template.sh` (refactored to use shared library)
