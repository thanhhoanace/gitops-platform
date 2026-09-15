# Sử dụng image base đã có sẵn (chứa kubectl và kustomize)
FROM line/kubectl-kustomize:latest

RUN apk add --no-cache curl tar gzip

ARG HELM_VERSION=v3.14.0
ENV HELM_VERSION ${HELM_VERSION}

RUN curl -sSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | \
    tar xz && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64

RUN helm version

# Thiết lập điểm vào mặc định
CMD ["bash"]
