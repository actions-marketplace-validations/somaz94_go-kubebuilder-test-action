# go-kubebuilder-test-action

[![CI](https://github.com/somaz94/go-kubebuilder-test-action/actions/workflows/ci.yml/badge.svg)](https://github.com/somaz94/go-kubebuilder-test-action/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Latest Tag](https://img.shields.io/github/v/tag/somaz94/go-kubebuilder-test-action)](https://github.com/somaz94/go-kubebuilder-test-action/tags)
[![Top Language](https://img.shields.io/github/languages/top/somaz94/go-kubebuilder-test-action)](https://github.com/somaz94/go-kubebuilder-test-action)
[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-Go%20Kubebuilder%20Test%20Action-blue?logo=github)](https://github.com/marketplace/actions/go-kubebuilder-test-action)

A composite GitHub Action that runs Go unit tests for a [kubebuilder](https://book.kubebuilder.io/)-based controller/operator and verifies that the generated manifests and deepcopy code are in sync with the source — in a single step.

It replaces the four-step inline block every kubebuilder repo tends to copy (`setup-go` → `go mod tidy` → `make test` → `make manifests generate && git diff --exit-code`).

<br/>

## Features

- One action, whole kubebuilder test flow: `setup-go` → optional `go mod tidy` → test command → optional `make manifests generate` drift check
- Defaults match the standard kubebuilder layout (`go.mod`, `make test`, `make manifests generate`, paths `config/ api/`) — zero config for most repos
- Tunable: custom `test_command`, custom `verify_command`, custom `verify_paths`, pinned `go_version`, subdirectory `working_directory`
- Explicit `verify_manifests` toggle for repos that don't use kubebuilder's generators
- Writes a per-run summary table to `$GITHUB_STEP_SUMMARY`
- Exposes `test_exit_code` and `manifests_drift` outputs for downstream steps

<br/>

## Requirements

- **Runner OS**: `ubuntu-latest` (the action shells out to `git`, `go`, `make`, `bash` — any runner with those works).
- **Caller must run `actions/checkout`** before this action (the git diff check relies on a real working tree).
- **`make` + kubebuilder targets** available in the repo when `verify_manifests: true` (default). If you don't have `make manifests generate`, either override `verify_command` or set `verify_manifests: false`.

<br/>

## Quick Start

Drop this into `.github/workflows/test.yml` of any kubebuilder repo:

```yaml
name: Tests

on:
  push:
    branches: [main]
    paths-ignore:
      - '.github/workflows/**'
      - '**/*.md'
  pull_request:
  workflow_dispatch:

jobs:
  test:
    name: Run on Ubuntu
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: somaz94/go-kubebuilder-test-action@v1
```

With all defaults it runs: `setup-go` from `go.mod` → `go mod tidy` → `make test` → `make manifests generate && git diff --exit-code -- config/ api/`.

<br/>

## Usage

### Pin the Go version explicitly

```yaml
- uses: actions/checkout@v6
- uses: somaz94/go-kubebuilder-test-action@v1
  with:
    go_version: '1.22'
```

<br/>

### Use a custom test command

```yaml
- uses: actions/checkout@v6
- uses: somaz94/go-kubebuilder-test-action@v1
  with:
    test_command: 'go test ./... -race -coverprofile=cover.out'
```

<br/>

### Disable the manifest drift check

For Go modules that don't use kubebuilder generators:

```yaml
- uses: actions/checkout@v6
- uses: somaz94/go-kubebuilder-test-action@v1
  with:
    verify_manifests: false
```

<br/>

### Kubebuilder project in a subdirectory

```yaml
- uses: actions/checkout@v6
- uses: somaz94/go-kubebuilder-test-action@v1
  with:
    working_directory: operator
    go_version_file: go.mod
```

<br/>

### Custom verify command and paths

If your project uses different generator targets or keeps generated code under other directories:

```yaml
- uses: actions/checkout@v6
- uses: somaz94/go-kubebuilder-test-action@v1
  with:
    verify_command: 'make generate-all'
    verify_paths: 'apis/ config/ internal/generated/'
```

<br/>

### Consume the outputs

```yaml
- id: kbt
  uses: somaz94/go-kubebuilder-test-action@v1

- name: Report
  if: always()
  run: |
    echo "test_exit_code=${{ steps.kbt.outputs.test_exit_code }}"
    echo "manifests_drift=${{ steps.kbt.outputs.manifests_drift }}"
```

<br/>

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `go_version_file` | Path to `go.mod` (or another file) used by `actions/setup-go` as `go-version-file`. Ignored when `go_version` is set. | No | `go.mod` |
| `go_version` | Explicit Go version (e.g., `1.22`). Takes precedence over `go_version_file` when non-empty. | No | `''` |
| `working_directory` | Directory to run all commands in (Go module root). | No | `.` |
| `test_command` | Test command executed from `working_directory` (e.g., `make test`, `go test ./...`). | No | `make test` |
| `run_mod_tidy` | When `true`, run `go mod tidy` before the test command. | No | `true` |
| `verify_manifests` | When `true`, run `verify_command` and fail the action if `verify_paths` have any diff. | No | `true` |
| `verify_command` | Command that regenerates manifests/deepcopy before the git-diff check. | No | `make manifests generate` |
| `verify_paths` | Space-separated paths passed to `git diff --exit-code --` after `verify_command`. | No | `config/ api/` |
| `cache` | Enable Go module/build cache in `actions/setup-go`. | No | `true` |

<br/>

## Outputs

| Output | Description |
|--------|-------------|
| `test_exit_code` | Exit code of the test command. Always `0` when the action succeeds (the action fails otherwise). |
| `manifests_drift` | `true` when `verify_command` produced changes under `verify_paths` (the action also fails in that case); `false` when clean or verification skipped. |

<br/>

## Permissions

The action itself needs no special permissions beyond what `actions/checkout` and `actions/setup-go` require. A typical caller:

```yaml
permissions:
  contents: read
```

<br/>

## How It Works

1. **Validate inputs** — `go_version` or `go_version_file` must be set; `working_directory` must exist.
2. **`actions/setup-go`** — either from `go_version_file` (default) or `go_version` (when explicitly set). Go module/build cache controlled by `cache`.
3. **`go mod tidy`** — optional, matches the pattern every repo's inline workflow already uses.
4. **Test command** — `bash -c "$test_command"` run from `working_directory`. Exit code emitted as the `test_exit_code` output.
5. **Manifest drift check** (when `verify_manifests: true`):
   - Runs `verify_command` (default `make manifests generate`)
   - `git diff --exit-code -- <verify_paths>` — if anything under those paths changed, the action fails with `::error::Generated manifests or deepcopy are out of date. Run '<verify_command>' and commit the changes.` and exports `manifests_drift=true`.
6. **Summary** — a markdown table (working directory / test command / verify settings / result) is appended to `$GITHUB_STEP_SUMMARY`.

<br/>

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
