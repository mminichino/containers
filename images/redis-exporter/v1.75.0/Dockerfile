#
#

FROM docker.io/bitnami/minideb:bookworm

RUN apt-get update && apt-get upgrade -y && apt-get install -y curl && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG VERSION=latest
ARG TARGETARCH

RUN curl -L -s -o /tmp/redis_exporter.tar.gz \
    https://github.com/oliver006/redis_exporter/releases/download/${VERSION}/redis_exporter-${VERSION}.linux-${TARGETARCH}.tar.gz

WORKDIR /tmp

RUN tar xzf /tmp/redis_exporter.tar.gz && \
    mv /tmp/redis_exporter-*.linux-*/redis_exporter /usr/local/bin && \
    rm -rf /tmp/redis_exporter*

RUN groupadd -g 1001 exporter && \
    useradd -u 1001 -m -s /bin/bash -g exporter exporter

RUN mkdir -p /home/exporter/config && \
    chown -R 1001:1001 /home/exporter/config

EXPOSE 9121

WORKDIR /home/exporter
USER 1001:1001

ENTRYPOINT [ "redis_exporter" ]
