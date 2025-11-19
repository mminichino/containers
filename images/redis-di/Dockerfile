FROM ubuntu:20.04

RUN apt-get update && apt-get upgrade -y && apt-get install -y curl sudo && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN mkdir -p /usr/local/bin
COPY source/redis-di /usr/local/bin

RUN groupadd -g 1001 redis && \
    useradd -u 1001 -m -s /bin/bash -g redis redis

RUN echo "redis ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /home/redis
USER 1001:1001

ENTRYPOINT ["tail", "-f", "/dev/null"]
