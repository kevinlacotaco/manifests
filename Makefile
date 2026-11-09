SHELL := /bin/bash
ROOT := $(CURDIR)
BIN := $(ROOT)/.bin
VENV := $(ROOT)/.venv
export PATH := $(BIN):$(VENV)/bin:$(PATH)

.PHONY: tools validate render secrets clean

tools:
	./hack/install-tools.sh

validate: tools
	./hack/validate.sh
	./.bin/gitleaks dir . --config .gitleaks.toml --redact --no-banner

secrets: tools
	./.bin/gitleaks dir . --config .gitleaks.toml --redact --no-banner

render: tools
	./hack/render-helm.sh

clean:
	rm -rf .tmp
