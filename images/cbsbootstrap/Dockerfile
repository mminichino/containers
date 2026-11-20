FROM debian:bookworm-slim AS cbctl

ARG TARGETARCH
ARG CBCTL_VERSION=0.7.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# Download the static Go cbctl release binary and verify it against checksums.txt.
RUN set -eux; \
    case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      amd64) asset_arch=x86_64 ;; \
      arm64) asset_arch=arm64 ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    asset="cbctl_Linux_${asset_arch}.tar.gz"; \
    base="https://github.com/mminichino/cbctl/releases/download/v${CBCTL_VERSION}"; \
    cd /tmp; \
    curl -fsSL -O "${base}/${asset}"; \
    curl -fsSL -O "${base}/checksums.txt"; \
    grep " ${asset}\$" checksums.txt | sha256sum -c -; \
    tar -xzf "${asset}" cbctl; \
    install -m 0755 cbctl /usr/local/bin/cbctl; \
    /usr/local/bin/cbctl --version

FROM debian:bookworm-slim

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends bash ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

COPY --from=cbctl /usr/local/bin/cbctl /usr/local/bin/cbctl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN groupadd -g 1001 cbsbootstrap && \
    useradd -u 1001 -m -s /bin/bash -g cbsbootstrap cbsbootstrap

USER 1001:1001
ENTRYPOINT ["/entrypoint.sh"]
