SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)

ORG ?= rancher
PKG ?= github.com/kubernetes/kubernetes
SRC ?= github.com/kubernetes/kubernetes
TAG ?= ${GITHUB_ACTION_TAG}
K3S_ROOT_VERSION ?= v0.13.0

BUILD_META := -build$(shell date +%Y%m%d)
RUNNER := docker
IMAGE_BUILDER := $(RUNNER) buildx
IMAGE := $(ORG)/hardened-kubernetes:$(TAG)
TARGET_PLATFORMS ?= linux/amd64,linux/arm64

ifeq ($(TAG),)
TAG := v1.29.3-rke2dev$(BUILD_META)
endif

GOLANG_VERSION := $(shell ./scripts/golang-version.sh $(TAG))

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker build \
		--pull \
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

.PHONY: push-image
push-image:
	$(IMAGE_BUILDER) build \
		--sbom=true --attest type=provenance,mode=max \
		--build-arg VERSION=$(VERSION) \
		--build-arg GOLANG_VERSION=$(GOLANG_VERSION)
		--build-arg TAG=$(TAG) \
		--platform=$(TARGET_PLATFORMS) -t "$(IMAGE)" --push .
	@echo "Pushed $(IMAGE)"


.PHONY: scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --skip-db-update --ignore-unfixed $(ORG)/hardened-kubernetes:$(TAG)-linux-$(ARCH)

PHONY: log
log:
	@echo "TAG=$(TAG)"
	@echo "ORG=$(ORG)"
	@echo "PKG=$(PKG)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "K3S_ROOT_VERSION=$(K3S_ROOT_VERSION)"
	@echo "UNAME_M=$(UNAME_M)"
	@echo "GOLANG_VERSION=$(GOLANG_VERSION)"