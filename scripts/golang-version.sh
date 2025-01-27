#!/usr/bin/env bash

set -x

cd $(dirname $0)

which yq > /dev/null || go install github.com/mikefarah/yq/v4@v4.35.2

if [ -z "$1" ]; then
  echo "usage: $(basename "$0") <TAG> [GITHUB_REPO] [GITHUB_TOKEN]"
  exit 1
fi

TAG="$1"
UPSTREAM_GITHUB_REPO="${2:-kubernetes/kubernetes}"
UPSTREAM_GITHUB_TOKEN="$3"
K8S_VERSION=$(./semver-parse.sh "$TAG" all)

if [ -z "${K8S_VERSION}" ] || [ "${K8S_VERSION}" == "v.." ]; then
  echo "No Kubernetes version found in tag ${TAG}"
  exit 1
fi

GO_VERSION_URL="https://raw.githubusercontent.com/${UPSTREAM_GITHUB_REPO}/${K8S_VERSION}/.go-version"

if [ -n "${UPSTREAM_GITHUB_TOKEN}" ]; then
  GO_VERSION=$(curl -sL -H "authorization: token ${UPSTREAM_GITHUB_TOKEN}" "${GO_VERSION_URL}")
else
  GO_VERSION=$(curl -sL "${GO_VERSION_URL}")
fi
if [[ "${GO_VERSION}" != "1."* ]]; then
  echo "No Go version found for Kubernetes ${K8S_VERSION}"
  exit 1
fi

BASE_URL='https://hub.docker.com/v2/repositories/rancher/hardened-build-base/tags'
NEXT_URL=$BASE_URL
MAX_PAGE=10
PAGE=0
TAG=""

while [ -n "${NEXT_URL}" ] && [ $PAGE -lt $MAX_PAGE ]; do
  RESPONSE=$(curl -s "$NEXT_URL")
  NEXT_URL=$(echo "$RESPONSE" | yq -r '.next // ""')
  TAGS=$(echo "$RESPONSE" | yq -r '.results[].name')
  TAG=$(echo "${TAGS}" | grep "${GO_VERSION}b[0-9+]$" | head -n 1)
  if [ -n "$TAG" ]; then
    break
  fi
  
  PAGE=$((PAGE + 1))
done

if [ -z "${TAG}" ]; then
  echo "No hardened-build-base tag found for Go ${GO_VERSION}"
  exit 1
fi

echo "${TAG}"
