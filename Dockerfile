ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=briandowns/rancher-build-base:v0.1.1

FROM ${UBI_IMAGE} as ubi

FROM ${GO_IMAGE} as builder
ARG TAG="" 
RUN apt update     && \ 
    apt upgrade -y && \ 
    apt install -y ca-certificates git bash rsync

RUN git clone --depth=1 https://github.com/kubernetes/kubernetes.git
RUN cd /go/kubernetes                  && \
    git fetch --all --tags --prune     && \
    git checkout tags/${TAG} -b ${TAG} && \
	make all

FROM ubi
RUN microdnf update -y && \ 
	rm -rf /var/cache/yum

COPY --from=builder /go/kubernetes/_output/bin /usr/local/bin
