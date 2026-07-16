FROM python:3.12-slim-bookworm

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends bash ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

ARG VERSION=latest
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir "couchbase-connect-py>=${VERSION}"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN groupadd -g 1001 cbsbootstrap && \
    useradd -u 1001 -m -s /bin/bash -g cbsbootstrap cbsbootstrap

USER 1001:1001
ENTRYPOINT ["/entrypoint.sh"]
