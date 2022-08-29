#!/usr/bin/env bash

set -x

cd $(dirname $0)

BUILD_BASE_RELEASE_URL=https://api.github.com/repos/rancher/image-build-base/releases
BUILD_BASE_REQ_HEADERS="Accept: application/vnd.github+json"
which yq > /dev/null || go install github.com/mikefarah/yq/v4@v4.23.1

which jq > /dev/null || curl -Ss -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x /usr/bin/jq

K8S_VERSION=$(./semver-parse.sh $1 all)

DEPENDENCIES_URL="https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/build/dependencies.yaml"
GOLANG_VERSION=$(curl -sL "${DEPENDENCIES_URL}" | yq e '.dependencies[] | select(.name == "golang: upstream version").version' -)

GOBORING_TAG=$(curl -s -H ${BUILD_BASE_REQ_HEADERS} ${BUILD_BASE_RELEASE_URL} | jq '.[] | select(.tag_name| contains("'"${GOLANG_VERSION}"'"))' | jq -r .tag_name | head -1)
echo ${GOBORING_TAG}
