SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)

PKG ?= github.com/kubernetes/kubernetes
SRC ?= github.com/kubernetes/kubernetes
TAG ?= ${GITHUB_ACTION_TAG}
K3S_ROOT_VERSION ?= v0.14.1

BUILD_META := -build$(shell date +%Y%m%d)

ifeq ($(TAG),)
TAG := v1.29.3-rke2dev$(BUILD_META)
endif

ARCH=
ifeq ($(UNAME_M), x86_64)
	ARCH=amd64
else ifeq ($(UNAME_M), aarch64)
	ARCH=arm64
else 
	ARCH=$(UNAME_M)
endif

ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

REPO ?= rancher
IMAGE ?= $(REPO)/hardened-kubernetes:$(shell echo $(TAG) | sed -e 's/+/-/g')

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
		--tag $(IMAGE)-linux-$(ARCH) \
		.

.PHONY: all
all:
	docker build \
		--build-arg K8S_TAG=$(shell echo $(TAG) | grep -oP "^v(([0-9]+)\.([0-9]+)\.([0-9]+))") \
		--build-arg TAG=$(TAG) -t $(IMAGE) .

.PHONY: image-push
image-push:
	docker push $(IMAGE) >> /dev/null

.PHONY: push-image
push-image:
	docker buildx build \
		$(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--build-arg GO_IMAGE=rancher/hardened-build-base:$(GOLANG_VERSION) \
		--build-arg K3S_ROOT_VERSION=$(K3S_ROOT_VERSION) \
		--build-arg K8S_TAG=$(shell echo $(TAG) | grep -oP "^v(([0-9]+)\.([0-9]+)\.([0-9]+))") \
		--tag $(IMAGE) \
		--push \
		.

.PHONY: scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --skip-db-update --ignore-unfixed $(IMAGE)-linux-$(ARCH)

PHONY: log
log:
	@echo "TAG=$(TAG)"
	@echo "PKG=$(PKG)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "K3S_ROOT_VERSION=$(K3S_ROOT_VERSION)"
	@echo "UNAME_M=$(UNAME_M)"
	@echo "GOLANG_VERSION=$(GOLANG_VERSION)"
