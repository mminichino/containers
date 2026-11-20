.PHONY:	dev prod
export PYTHONPATH := $(shell pwd)/tests:$(shell pwd):$(PYTHONPATH)
export PROJECT_NAME := $$(basename $$(pwd))
export PROJECT_VERSION := $(shell cat VERSION)
# Go cbctl release bundled into the image (https://github.com/mminichino/cbctl)
export CBCTL_VERSION := 0.7.0

dev:
		docker build --build-arg CBCTL_VERSION=$(CBCTL_VERSION) -t cbsbootstrap:$(PROJECT_VERSION) .
prod:
		docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg CBCTL_VERSION=$(CBCTL_VERSION) \
		--sbom=true \
		--provenance=true \
		-t mminichino/cbsbootstrap:$(PROJECT_VERSION) \
		--push \
		.
