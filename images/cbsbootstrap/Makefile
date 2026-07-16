.PHONY:	dev prod
export PYTHONPATH := $(shell pwd)/tests:$(shell pwd):$(PYTHONPATH)
export PROJECT_NAME := $$(basename $$(pwd))
export PROJECT_VERSION := $(shell cat VERSION)

dev:
		docker build --build-arg VERSION=$(PROJECT_VERSION) -t cbsbootstrap:$(PROJECT_VERSION) .
prod:
		docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg VERSION=$(PROJECT_VERSION) \
		--sbom=true \
		--provenance=true \
		-t mminichino/cbsbootstrap:$(PROJECT_VERSION) \
		--push \
		.
