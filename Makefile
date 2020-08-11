SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build \
	--build-arg K8S_TAG=$(shell echo $(TAG) | grep -oP "^v(([0-9]+)\.([0-9]+)\.([0-9]+))") \
	--build-arg TAG=$(TAG) -t rancher/kubernetes:$(shell echo $(TAG) | sed -e 's/+/-/g') .

.PHONY: image-push
image-push:
	docker push rancher/kubernetes:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/kubernetes:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/kubernetes:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/kubernetes:$(TAG) \
		$(shell docker image inspect rancher/kubernetes:$(TAG) | jq -r '.[] | .RepoDigests[0]')
