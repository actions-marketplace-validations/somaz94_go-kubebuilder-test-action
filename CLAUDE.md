# CLAUDE.md

<br/>

## Project Structure

- Composite GitHub Action (no Docker image — `runs.using: composite`)
- Replaces the 4-step inline block every kubebuilder repo copy-pastes: `setup-go` → `go mod tidy` → `make test` → `make manifests generate && git diff --exit-code -- config/ api/`
- Defaults match standard kubebuilder scaffolds; all inputs are overridable for non-standard layouts
- Drift detection is the central guarantee: if `verify_command` regenerates anything under `verify_paths`, the action fails loud — matching the manual `::error::Generated manifests or deepcopy are out of date...` workflow pattern

<br/>

## Key Files

- `action.yml` — composite action (**9 inputs**, **2 outputs**). Two `setup-go` steps gated on `go_version` empty/non-empty, then test → verify → summary. All `run:` steps use `working-directory: ${{ inputs.working_directory }}` so subdirectory kubebuilder projects work without extra wiring.
- `tests/fixtures/sample_operator/` — minimal Go module (`go.mod`, `Makefile` with no-op `manifests`/`generate`, `pkg/hello` with a test, placeholder `api/v1/doc.go` + `config/crd/bases/.gitkeep` for drift paths). Used by both `ci.yml` and `use-action.yml`.
- `cliff.toml` — git-cliff config for release notes.
- `Makefile` — `lint` (dockerized yamllint), `test` (runs the fixture locally via `make test`), `fixtures`, `clean`.

<br/>

## Build & Test

There is no local "build" — composite actions execute on the GitHub Actions runner.

```bash
make lint         # yamllint action.yml + workflows + fixtures
make test         # runs `make test` inside tests/fixtures/sample_operator
make fixtures     # list fixture files (sanity check)
make clean        # remove Go test caches inside the fixture
```

Local `make test` requires `go` on PATH; `make lint` only needs Docker.

<br/>

## Workflows

- `ci.yml` — `lint` (yamllint + actionlint) + `test-action` (defaults, expect `test_exit_code=0`, `manifests_drift=false`) + `test-action-custom` (custom `test_command`, `verify_manifests=false`) + `test-action-drift` (injects drift via `verify_command`, `continue-on-error: true`, asserts the action failed with `manifests_drift=true`) + `ci-result` aggregator.
- `release.yml` — git-cliff release notes + `softprops/action-gh-release@v3` + `somaz94/major-tag-action@v1` for the `v1` sliding tag.
- `use-action.yml` — post-release smoke test. Runs `somaz94/go-kubebuilder-test-action@v1` against the fixture in two flavours: defaults (expect success) and injected drift (expect failure + `manifests_drift=true`).
- `gitlab-mirror.yml`, `changelog-generator.yml`, `contributors.yml`, `dependabot-auto-merge.yml`, `issue-greeting.yml`, `stale-issues.yml` — standard repo automation shared with sibling `somaz94/ansible-*-action` repos.

<br/>

## Release

Push a `vX.Y.Z` tag → `release.yml` runs → GitHub Release published → `v1` major tag updated → `use-action.yml` smoke-tests the published version against the fixture (both defaults and drift paths).

<br/>

## Action Inputs

Required: none (fully default-driven for kubebuilder-style projects).

Tuning: `go_version` / `go_version_file`, `working_directory` (default `.`), `test_command` (default `make test`), `run_mod_tidy` (default `true`), `verify_manifests` (default `true`), `verify_command` (default `make manifests generate`), `verify_paths` (default `config/ api/`), `cache` (default `true`).

See [README.md](README.md) for the full table.

<br/>

## Internal Flow

1. **Validate inputs** — either `go_version` or `go_version_file` must be set; `working_directory` must exist.
2. **`actions/setup-go`** — gated on `go_version` being non-empty. When `working_directory != '.'`, `go-version-file` is rewritten to `${working_directory}/${go_version_file}` so `actions/setup-go` finds the right file from the repo root.
3. **`go mod tidy`** — optional, on by default.
4. **Test command** — `bash -c "$test_command"` from `working_directory`. `test_exit_code=0` is emitted only on success (the action fails on non-zero exit, matching every inline workflow it replaces).
5. **Verify manifests** — single step, branches on `verify_manifests`:
   - `verify_manifests != 'true'` → emit `manifests_drift=false`, log a `::notice::`, exit 0
   - `verify_manifests == 'true'` → run `verify_command`, then `git diff --exit-code -- <verify_paths>` (space-split into an array so paths survive shell quoting)
     - Clean → `manifests_drift=false`
     - Dirty → `manifests_drift=true` + `::error::Generated manifests or deepcopy are out of date. Run '<verify_command>' and commit the changes.` + `exit 1`
   - The unified step ensures the `manifests_drift` top-level output is always populated (a separate skip-step would leave the output empty because composite `outputs.<name>.value` only tracks a single `steps.<id>`).
6. **Summary** — a markdown table (working directory / test command / verify settings / pass marker) is appended to `$GITHUB_STEP_SUMMARY`.
