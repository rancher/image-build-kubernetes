#!/usr/bin/env bash

set -x

cd $(dirname $0)

BUILD_BASE_RELEASE_URL=https://api.github.com/repos/rancher/image-build-base/releases
BUILD_BASE_REQ_HEADERS="Accept: application/vnd.github+json"
BUILD_BASE_TOKEN_HEADER="Authorization: Bearer $2"
if [ "${2}" == "" ]; then
    BUILD_BASE_TOKEN_HEADER=""
fi

which yq > /dev/null || go install github.com/mikefarah/yq/v4@v4.23.1
which jq > /dev/null || apk add -q --no-progress jq

K8S_VERSION=$(./semver-parse.sh $1 all)

DEPENDENCIES_URL="https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/build/dependencies.yaml"
GOLANG_VERSION=$(curl -sL "${DEPENDENCIES_URL}" | yq e '.dependencies[] | select(.name == "golang: upstream version").version' -)

GOBORING_TAG=$(curl -s -H "${BUILD_BASE_TOKEN_HEADER}" -H "${BUILD_BASE_REQ_HEADERS}" ${BUILD_BASE_RELEASE_URL} | jq -r '[ .[] | select(.tag_name|contains("'${GOLANG_VERSION}'")) | .tag_name ] | sort | last')
if [ -z "${BUILD_BASE_TOKEN_HEADER}" ]; then
    GOBORING_TAG=$(curl -s -H "${BUILD_BASE_REQ_HEADERS}" ${BUILD_BASE_RELEASE_URL} | jq -r '[ .[] | select(.tag_name|contains("'${GOLANG_VERSION}'")) | .tag_name ] | sort | last')
fi
echo ${GOBORING_TAG}