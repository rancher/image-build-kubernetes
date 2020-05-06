SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t ranchertest/kubernetes:$(TAG) .

.PHONY: image-push
image-push:
	docker push ranchertest/kubernetes:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed ranchertest/kubernetes:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect ranchertest/kubernetes:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create ranchertest/kubernetes:$(TAG) \
		$(shell docker image inspect ranchertest/kubernetes:$(TAG) | jq -r \'.[] | .RepoDigests[0]\')
