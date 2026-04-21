.PHONY: lint test test-fixture fixtures clean help

FIXTURE := tests/fixtures/sample_operator

## Quality

lint: ## yamllint action.yml + workflows + fixtures (dockerized, no host install)
	docker run --rm -v $$(pwd):/data cytopia/yamllint -d relaxed action.yml .github/workflows/ tests/

## Testing

test: test-fixture ## Run the fixture test locally (requires Go)

test-fixture: ## Run `make test` inside the fixture operator
	cd $(FIXTURE) && make test

## Fixtures

fixtures: ## List fixture files (committed — nothing to generate)
	@ls -R $(FIXTURE)

## Cleanup

clean: ## Remove Go test/build artefacts from the fixture
	cd $(FIXTURE) && go clean -testcache ./... || true
	rm -f $(FIXTURE)/**/*.test $(FIXTURE)/**/cover.out

## Help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
