FROM ubuntu:20.04

RUN apt-get update && apt-get upgrade -y && apt-get install -y curl apt-transport-https ca-certificates gnupg

RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
      gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

RUN echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | \
      tee /etc/apt/sources.list.d/kubernetes.list

RUN apt-get update && \
    apt-get install -y kubectl && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN mkdir -p /usr/local/bin
COPY source/redis-di /usr/local/bin
COPY source/rdi-setup.sh /usr/local/bin

RUN groupadd -g 1001 redis && \
    useradd -u 1001 -m -s /bin/bash -g redis redis

WORKDIR /home/redis
USER 1001:1001

ENTRYPOINT ["tail", "-f", "/dev/null"]
