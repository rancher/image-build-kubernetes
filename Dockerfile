ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.15.8b5

FROM ${UBI_IMAGE} as ubi

FROM ${GO_IMAGE} as builder
ARG K8S_TAG=""
ARG TAG=""

RUN apt update     && \ 
    apt upgrade -y && \ 
    apt install -y ca-certificates git bash rsync

RUN git clone --depth=1 https://github.com/kubernetes/kubernetes.git
RUN cd /go/kubernetes                          && \
    git fetch --all --tags --prune             && \
    git checkout tags/${K8S_TAG} -b ${K8S_TAG} && \
    KUBE_GIT_VERSION=${TAG} make all

FROM ubi
RUN microdnf update -y           && \
    microdnf install -y iptables && \
    rm -rf /var/cache/yum

COPY --from=builder /go/kubernetes/_output/bin /usr/local/bin

