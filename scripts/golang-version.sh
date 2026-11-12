#!/usr/bin/env bash

set -x

cd $(dirname $0)

which yq > /dev/null || go install github.com/mikefarah/yq/v4@a198f72367ce9da70b564a2cc25399de8e27bf37 #v4.35.2

K8S_VERSION=$(./semver-parse.sh "$1" all)

if [ -z "${K8S_VERSION}" ] || [ "${K8S_VERSION}" == "v.." ]; then
  echo "No Kubernetes version found in tag ${1}"
  exit 1
fi

GO_VERSION_URL="https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/.go-version"
GO_MINOR_VERSION=$(curl -sL "${GO_VERSION_URL}" | cut -d. -f1-2)

if [[ "${GO_MINOR_VERSION}" != "1."* ]]; then
  echo "No Go version found for Kubernetes ${K8S_VERSION}"
  exit 1
fi

BASE_URL='https://hub.docker.com/v2/repositories/rancher/hardened-build-base/tags?page_size=100'
NEXT_URL=$BASE_URL
MAX_PAGE=100
PAGE=0
ALL_TAGS=""

# Docker Hub does not return tags in version order, so collect matches from
# every page first and only then pick the highest version.
while [ -n "${NEXT_URL}" ] && [ "${PAGE}" -lt "${MAX_PAGE}" ]; do
  RESPONSE=$(curl -sf "${NEXT_URL}") || { echo "Failed to fetch ${NEXT_URL}"; exit 1; }
  NEXT_URL=$(echo "${RESPONSE}" | yq -r '.next // ""')
  ALL_TAGS+=$(echo "${RESPONSE}" | yq -r '.results[].name')$'\n'
  PAGE=$((PAGE + 1))
done

TAG=$(echo "${ALL_TAGS}" \
  | grep -E "^v${GO_MINOR_VERSION//./\\.}\.[0-9]+b[0-9]+$" \
  | sort -V \
  | tail -n 1 || true)

if [ -z "${TAG}" ]; then
  echo "No hardened-build-base tag found for Go ${GO_MINOR_VERSION}"
  exit 1
fi

echo "${TAG}"
