SHELL := /bin/bash
ROOT := $(CURDIR)
BIN := $(ROOT)/.bin
VENV := $(ROOT)/.venv
export PATH := $(BIN):$(VENV)/bin:$(PATH)

.PHONY: tools validate clean

tools:
	./hack/install-tools.sh

validate: tools
	./hack/validate.sh

clean:
	rm -rf .tmp
