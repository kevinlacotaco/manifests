SHELL := /bin/bash
ROOT := $(CURDIR)
BIN := $(ROOT)/.bin
VENV := $(ROOT)/.venv
export PATH := $(BIN):$(VENV)/bin:$(PATH)

.PHONY: tools validate render clean

tools:
	./hack/install-tools.sh

validate: tools
	./hack/validate.sh

render: tools
	./hack/render-helm.sh

clean:
	rm -rf .tmp
