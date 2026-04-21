# sample_operator (fixture)

Minimal Go module used by `ci.yml` to exercise `somaz94/go-kubebuilder-test-action`.

- `go.mod` — single-module, no external deps
- `Makefile` — `test`, `manifests`, `generate`, `fmt`, `vet`, `tidy`. `manifests` / `generate` are intentionally no-ops; a real kubebuilder project would invoke `controller-gen`. That's fine here: the action's contract is "run these targets, then fail if anything under `config/ api/` drifted", and a no-op keeps the drift check deterministic (no drift).
- `api/v1/doc.go` — gives the `api/` path real content for the drift check.
- `config/crd/bases/.gitkeep` — gives the `config/` path real content for the drift check.
- `pkg/hello/` — tiny package with a test so `make test` exercises `go test`.
