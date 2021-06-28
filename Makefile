SEVERITIES = HIGH,CRITICAL

ifeq ($(ARCH),)
ARCH=$(shell go env GOARCH)
endif

ifeq ($(KUBERNETES_VERSION),)
KUBERNETES_VERSION=v1.21.1
endif

ORG ?= rancher
PKG ?= github.com/kubernetes/kubernetes
SRC ?= github.com/kubernetes/kubernetes
TAG ?= ${DRONE_TAG}

ifeq ($(TAG),)
TAG := v1.21.1
endif


.PHONY: image-build
image-build:
	docker build \
		--pull \
		--build-arg ARCH=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG) \
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
		$(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH) \
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-kubernetes:$(TAG)
