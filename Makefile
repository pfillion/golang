SHELL = /bin/sh
.SUFFIXES:
.PHONY: help
.DEFAULT_GOAL := help

ifeq ($(MODE_LOCAL),true)
	GIT_CONFIG_GLOBAL := $(shell git config --global --add safe.directory /go/src/github.com/pfillion/helloworld > /dev/null)
endif

# Version
VERSION            := 1.25.5
VERSION_PARTS      := $(subst ., ,$(VERSION))
VERSION_ALPINE     := 3.23

MAJOR              := $(word 1,$(VERSION_PARTS))
MINOR              := $(word 2,$(VERSION_PARTS))
MICRO              := $(word 3,$(VERSION_PARTS))

CURRENT_VERSION_MICRO := $(MAJOR).$(MINOR).$(MICRO)
CURRENT_VERSION_MINOR := $(MAJOR).$(MINOR)
CURRENT_VERSION_MAJOR := $(MAJOR)

DATE                = $(shell date -u +"%Y-%m-%dT%H:%M:%S")
COMMIT             := $(shell git rev-parse HEAD)
AUTHOR             := $(firstword $(subst @, ,$(shell git show --format="%aE" $(COMMIT))))

# Docker parameters
ROOT_FOLDER=$(shell pwd)
NS ?= pfillion
IMAGE_NAME ?= golang
CONTAINER_NAME ?= golang
CONTAINER_INSTANCE ?= default

help: ## Show the Makefile help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

version: ## Show all versionning infos
	@echo CURRENT_VERSION_MICRO="$(CURRENT_VERSION_MICRO)"
	@echo CURRENT_VERSION_MINOR="$(CURRENT_VERSION_MINOR)"
	@echo CURRENT_VERSION_MAJOR="$(CURRENT_VERSION_MAJOR)"
	@echo VERSION_ALPINE="$(VERSION_ALPINE)"
	@echo DATE="$(DATE)"
	@echo COMMIT="$(COMMIT)"
	@echo AUTHOR="$(AUTHOR)"

build: ## Build the image form Dockerfile
	docker build \
		--build-arg DATE=$(DATE) \
		--build-arg CURRENT_VERSION_MICRO=$(CURRENT_VERSION_MICRO) \
		--build-arg VERSION_ALPINE=$(VERSION_ALPINE) \
		--build-arg COMMIT=$(COMMIT) \
		--build-arg AUTHOR=$(AUTHOR) \
		-t $(NS)/$(IMAGE_NAME):$(CURRENT_VERSION_MICRO) \
		-t $(NS)/$(IMAGE_NAME):$(CURRENT_VERSION_MINOR) \
		-t $(NS)/$(IMAGE_NAME):$(CURRENT_VERSION_MAJOR) \
		-t $(NS)/$(IMAGE_NAME):latest \
		-f Dockerfile .

push: ## Push the image to a registry
ifdef DOCKER_USERNAME
	@echo "$(DOCKER_PASSWORD)" | docker login -u "$(DOCKER_USERNAME)" --password-stdin
endif
	docker push $(NS)/$(IMAGE_NAME):$(CURRENT_VERSION_MICRO)
	docker push $(NS)/$(IMAGE_NAME):$(CURRENT_VERSION_MINOR)
	docker push $(NS)/$(IMAGE_NAME):$(CURRENT_VERSION_MAJOR)
	docker push $(NS)/$(IMAGE_NAME):latest
    
shell: ## Run shell command in the container
	docker run --rm --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) -i -t $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(IMAGE_NAME):$(CURRENT_VERSION_MICRO) /bin/sh

test: ## Run all tests
	container-structure-test test --image $(NS)/$(IMAGE_NAME):$(CURRENT_VERSION_MICRO) --config tests/config.yaml

test-ci: ## Run CI pipeline locally
	woodpecker-cli exec --local --repo-trusted-volumes=true --env=MODE_LOCAL=true			
	
release: build push ## Build and push the image to a registry