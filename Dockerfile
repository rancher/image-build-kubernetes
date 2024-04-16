ARG BCI_BASE_IMAGE=registry.suse.com/bci/bci-base:15.5
ARG BCI_BUSYBOX_IMAGE=registry.suse.com/bci/bci-busybox:15.5
ARG GO_IMAGE=rancher/hardened-build-base:v1.21.5b2

FROM ${BCI_BUSYBOX_IMAGE} as bci-busybox
FROM ${GO_IMAGE} as build
# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.3.0 as xx

FROM ${BCI_BASE_IMAGE} as bci-base
FROM --platform=$BUILDPLATFORM ${GO_IMAGE} as base-builder
COPY --from=xx / /
RUN apk add file make git clang lld tar
ARG TARGETPLATFORM
RUN set -x && \
    xx-apk --no-cache add \
    bash \
    binutils-gold \
    libc6-compat \
    curl \
    file \
    git \
    libseccomp-dev \
    rsync \
    make \
    gcc \
    py-pip \
    musl-dev \
    lld \
    clang

FROM --platform=$BUILDPLATFORM base-builder AS build-k8s-codegen
ARG TAG

COPY ./scripts/semver-parse.sh /semver-parse.sh
RUN chmod +x /semver-parse.sh

RUN echo $(/semver-parse.sh ${TAG} all)
RUN git clone -b $(/semver-parse.sh ${TAG} all) --depth=1 -- https://github.com/kubernetes/kubernetes.git ${GOPATH}/src/kubernetes
WORKDIR ${GOPATH}/src/kubernetes

# force code generation
RUN make WHAT=cmd/kube-apiserver
# build statically linked executables 
RUN echo "export MAJOR=$(/semver-parse.sh ${TAG} major)" >> /usr/local/go/bin/go-build-static-k8s.sh
RUN echo "export MINOR=$(/semver-parse.sh ${TAG} minor)" >> /usr/local/go/bin/go-build-static-k8s.sh
RUN echo "export GIT_COMMIT=$(git rev-parse HEAD)" >> /usr/local/go/bin/go-build-static-k8s.sh
RUN echo "export KUBERNETES_VERSION=$(/semver-parse.sh ${TAG} k8s)" >> /usr/local/go/bin/go-build-static-k8s.sh
RUN echo "export BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /usr/local/go/bin/go-build-static-k8s.sh
RUN echo "export GO_LDFLAGS=\"-linkmode=external \
    -X k8s.io/component-base/version.gitVersion=\${KUBERNETES_VERSION} \
    -X k8s.io/component-base/version.gitMajor=\${MAJOR} \
    -X k8s.io/component-base/version.gitMinor=\${MINOR} \
    -X k8s.io/component-base/version.gitCommit=\${GIT_COMMIT} \
    -X k8s.io/component-base/version.gitTreeState=clean \
    -X k8s.io/component-base/version.buildDate=\${BUILD_DATE} \
    -X k8s.io/client-go/pkg/version.gitVersion=\${KUBERNETES_VERSION} \
    -X k8s.io/client-go/pkg/version.gitMajor=\${MAJOR} \
    -X k8s.io/client-go/pkg/version.gitMinor=\${MINOR} \
    -X k8s.io/client-go/pkg/version.gitCommit=\${GIT_COMMIT} \
    -X k8s.io/client-go/pkg/version.gitTreeState=clean \
    -X k8s.io/client-go/pkg/version.buildDate=\${BUILD_DATE} \
    \"" >> /usr/local/go/bin/go-build-static-k8s.sh
RUN echo 'go-build-static.sh -gcflags=-trimpath=${GOPATH}/src/kubernetes -mod=vendor -tags=selinux,osusergo,netgo ${@}' \
    >> /usr/local/go/bin/go-build-static-k8s.sh
RUN chmod -v +x /usr/local/go/bin/go-*.sh

FROM --platform=$BUILDPLATFORM build-k8s-codegen AS build-k8s
ARG ARCH="amd64"
ARG K3S_ROOT_VERSION="v0.13.0"
ADD https://github.com/k3s-io/k3s-root/releases/download/${K3S_ROOT_VERSION}/k3s-root-${ARCH}.tar /opt/k3s-root/k3s-root.tar
RUN tar xvf /opt/k3s-root/k3s-root.tar -C /opt/k3s-root --wildcards --strip-components=2 './bin/aux/*tables*'
RUN tar xvf /opt/k3s-root/k3s-root.tar -C /opt/k3s-root './bin/ipset'

# cross-compilation setup
ARG TARGETPLATFORM
RUN xx-go --wrap && go-build-static-k8s.sh -o bin/kube-apiserver          ./cmd/kube-apiserver
RUN xx-go --wrap && go-build-static-k8s.sh -o bin/kube-controller-manager ./cmd/kube-controller-manager
RUN xx-go --wrap && go-build-static-k8s.sh -o bin/kube-scheduler          ./cmd/kube-scheduler
RUN xx-go --wrap && go-build-static-k8s.sh -o bin/kube-proxy              ./cmd/kube-proxy
RUN xx-go --wrap && go-build-static-k8s.sh -o bin/kubeadm                 ./cmd/kubeadm
RUN xx-go --wrap && go-build-static-k8s.sh -o bin/kubectl                 ./cmd/kubectl
RUN xx-go --wrap && go-build-static-k8s.sh -o bin/kubelet                 ./cmd/kubelet
RUN go-assert-static.sh bin/*
RUN xx-verify --static bin/*
RUN if [ "${ARCH}" = "amd64" ]; then \
        go-assert-boring.sh bin/* ; \
    fi
RUN install -s bin/* /usr/local/bin/
RUN kube-proxy --version

FROM bci-base AS kernel-tools
FROM ${GO_IMAGE} as strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=build-k8s /usr/local/bin/ /kubernetes/
RUN strip /kubernetes/*

FROM bci-base AS kernel-tools
RUN zypper update -y && \
    zypper install -y which conntrack-tools kmod

FROM bci-busybox as kubernetes

COPY --from=kernel-tools /usr/lib64/conntrack-tools /usr/lib64/conntrack-tools
COPY --from=kernel-tools /usr/lib64/libmnl* /usr/lib64/libnetfilter* /usr/lib64/libnfnetlink* /usr/lib64/
COPY --from=kernel-tools /usr/sbin/conntrack /usr/sbin/conntrack
COPY --from=kernel-tools /usr/sbin/modprobe /usr/sbin/modprobe
COPY --from=build-k8s /opt/k3s-root/aux/ /usr/sbin/
COPY --from=build-k8s /opt/k3s-root/bin/ /bin/
COPY --from=strip_binary /kubernetes/ /usr/local/bin/
