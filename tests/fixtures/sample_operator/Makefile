.PHONY: test manifests generate fmt vet tidy

test:
	go test ./...

manifests:
	@echo "manifests (fixture noop — real kubebuilder projects invoke controller-gen)"

generate:
	@echo "generate (fixture noop — real kubebuilder projects invoke controller-gen)"

fmt:
	go fmt ./...

vet:
	go vet ./...

tidy:
	go mod tidy
