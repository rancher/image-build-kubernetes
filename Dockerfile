ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GOBORING_IMAGE_VER=1.13.8b4

FROM goboring/golang:${GOBORING_IMAGE_VER} as builder
RUN apt update                                              && \
    apt upgrade -y                                          && \
    apt install -y apt-utils ca-certificates git bash rsync && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/kubernetes/kubernetes.git && \
    cd kubernetes                                                    && \
    git fetch --all --tags --prune                                   && \
    git checkout tags/v1.17.0 -b v1.17.0
RUN cd /go/kubernetes && \
    make all

FROM ${UBI_IMAGE}
RUN microdnf update

COPY --from=builder /go/kubernetes/_output/bin /usr/local/bin