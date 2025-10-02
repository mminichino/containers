FROM alpine:latest

RUN apk update && apk upgrade && apk add --no-cache curl bash

ARG VERSION=stable
ARG TARGETARCH
RUN if [ "${VERSION}" = "stable" ]; then \
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt); \
    fi && \
    curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

RUN addgroup -g 1001 kubectl && \
    adduser -u 1001 -D -s /bin/bash -G kubectl kubectl
RUN mkdir -p /home/kubectl/.kube && chown -R kubectl:kubectl /home/kubectl/.kube

WORKDIR /home/kubectl
USER kubectl
ENTRYPOINT [ "kubectl" ]
CMD [ "--help" ]
