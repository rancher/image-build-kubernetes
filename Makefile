SEVERITIES = HIGH,CRITICAL
SHELL := /bin/bash -x

ifeq ($(ARCH),)
ARCH=$(shell go env GOARCH)
endif

ORG ?= rancher
PKG ?= github.com/kubernetes/kubernetes
SRC ?= github.com/kubernetes/kubernetes
TAG ?= ${DRONE_TAG}
K3S_ROOT_VERSION ?= v0.9.1

ifeq ($(ARCH),"s390x")
K3S_ROOT_VERSION = v0.10.0-rc.0
endif

BUILD_META := -build$(shell date +%Y%m%d)

ifeq ($(TAG),)
TAG := v1.21.3-rke2dev$(BUILD_META)
endif

GOLANG_VERSION := $(shell if echo $(TAG) | grep -qE '^v1\.(18|19|20)\.'; then echo v1.15.15b5; else echo v1.16.9b7; fi)

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker build \
		--pull \
		--build-arg ARCH=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG) \
		--build-arg GO_IMAGE=rancher/hardened-build-base:$(GOLANG_VERSION) \
		--build-arg K3S_ROOT_VERSION=$(K3S_ROOT_VERSION) \
		--tag $(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH) \
		.

.PHONY: all
all:
	docker build \
	--build-arg K8S_TAG=$(shell echo $(TAG) | grep -oP "^v(([0-9]+)\.([0-9]+)\.([0-9]+))") \
	--build-arg TAG=$(TAG) -t $(ORG)/hardened-kubernetes:$(shell echo $(TAG) | sed -e 's/+/-/g') .

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed $(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-kubernetes:$(TAG) \
		$(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-kubernetes:$(TAG)
