ARG BCI_BASE_IMAGE=registry.suse.com/bci/bci-base:15.5
ARG BCI_BUSYBOX_IMAGE=registry.suse.com/bci/bci-busybox:15.5
ARG GO_IMAGE=rancher/hardened-build-base:v1.22.7b1

FROM ${BCI_BASE_IMAGE} as bci-base
FROM ${BCI_BUSYBOX_IMAGE} as bci-busybox
FROM ${GO_IMAGE} as build
RUN set -x && \
    apk --no-cache add \
    bash \
    binutils-gold \
    libc6-compat \
    curl \
    file \
    git \
    libseccomp-dev \
    rsync \
    tar \
    make \
    gcc \
    py-pip

FROM build AS build-k8s-codegen
ARG TAG

COPY ./scripts/semver-parse.sh /semver-parse.sh
RUN chmod +x /semver-parse.sh

RUN echo $(/semver-parse.sh ${TAG} all)
RUN git clone -b $(/semver-parse.sh ${TAG} all) --depth=1 -- https://github.com/kubernetes/kubernetes.git ${GOPATH}/src/kubernetes
WORKDIR ${GOPATH}/src/kubernetes

# force code generation
RUN make WHAT=cmd/kube-apiserver
# build statically linked executables 
RUN MAJOR=$(/semver-parse.sh ${TAG} major) && \
    MINOR=$(/semver-parse.sh ${TAG} minor) && \
    GIT_COMMIT=$(git rev-parse HEAD) && \
    KUBERNETES_VERSION=$(/semver-parse.sh ${TAG} k8s) && \
    BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) && \
    echo "export MAJOR=${MAJOR}" >> /usr/local/go/bin/go-build-static-k8s.sh && \
    echo "export MINOR=${MINOR}" >> /usr/local/go/bin/go-build-static-k8s.sh && \
    echo "export GIT_COMMIT=${GIT_COMMIT}" >> /usr/local/go/bin/go-build-static-k8s.sh && \
    echo "export KUBERNETES_VERSION=${KUBERNETES_VERSION}" >> /usr/local/go/bin/go-build-static-k8s.sh && \
    echo "export BUILD_DATE=${BUILD_DATE}" >> /usr/local/go/bin/go-build-static-k8s.sh && \
    echo "export GO_LDFLAGS=\"-linkmode=external \
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
    \"" >> /usr/local/go/bin/go-build-static-k8s.sh && \
    echo 'go-build-static.sh -gcflags=-trimpath=${GOPATH}/src/kubernetes -mod=vendor -tags=selinux,osusergo,netgo ${@}' \
    >> /usr/local/go/bin/go-build-static-k8s.sh
RUN chmod -v +x /usr/local/go/bin/go-*.sh

## maybe here

FROM build-k8s-codegen AS build-k8s
ARG TARGETARCH
ARG K3S_ROOT_VERSION=v0.14.0
ADD https://github.com/k3s-io/k3s-root/releases/download/${K3S_ROOT_VERSION}/k3s-root-${TARGETARCH}.tar /opt/k3s-root/k3s-root.tar
RUN tar xvf /opt/k3s-root/k3s-root.tar -C /opt/k3s-root --wildcards --strip-components=2 './bin/aux/*tables*'
RUN tar xvf /opt/k3s-root/k3s-root.tar -C /opt/k3s-root './bin/ipset'

RUN go-build-static-k8s.sh -o bin/kube-apiserver          ./cmd/kube-apiserver && \
    go-build-static-k8s.sh -o bin/kube-controller-manager ./cmd/kube-controller-manager && \
    go-build-static-k8s.sh -o bin/kube-scheduler          ./cmd/kube-scheduler && \
    go-build-static-k8s.sh -o bin/kube-proxy              ./cmd/kube-proxy && \
    go-build-static-k8s.sh -o bin/kubeadm                 ./cmd/kubeadm && \
    go-build-static-k8s.sh -o bin/kubectl                 ./cmd/kubectl && \
    go-build-static-k8s.sh -o bin/kubelet                 ./cmd/kubelet

RUN go-assert-static.sh bin/*
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        go-assert-boring.sh bin/* ; \
    fi
RUN install -s bin/* /usr/local/bin/
RUN kube-proxy --version

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
COPY --from=build-k8s /usr/local/bin/ /usr/local/bin/
