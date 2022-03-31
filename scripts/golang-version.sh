#!/usr/bin/env bash

set -x

cd $(dirname $0)

which yq > /dev/null || go install github.com/mikefarah/yq/v4@v4.23.1

K8S_VERSION=$(./semver-parse.sh $1 all)
DEPENDENCIES_URL="https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/build/dependencies.yaml"
GOBORING_RELEASES_URL="https://raw.githubusercontent.com/golang/go/dev.boringcrypto/misc/boring/RELEASES"
GOLANG_VERSION=$(curl -sL "${DEPENDENCIES_URL}" | yq e '.dependencies[] | select(.name == "golang: upstream version").version' -)
GOBORING_VERSION=$(curl -sL  "${GOBORING_RELEASES_URL}" | awk "/${GOLANG_VERSION}b.+ [0-9a-f]+ src / {sub(/^go/, \"v\", \$1); print \$1}")

echo ${GOBORING_VERSION}
