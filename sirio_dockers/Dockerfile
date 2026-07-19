# Nebbie Server — ambiente Sirio (porta 4003).
# Build context: Server/ (parent di sirio_dockers/).

FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV DOCKER_BUILD=ON

COPY scripts/install-odb-toolchain.sh /usr/local/sbin/install-odb-toolchain.sh
RUN chmod +x /usr/local/sbin/install-odb-toolchain.sh

RUN apt-get update && \
    apt-get install -y \
        sudo git php8.3-cli gcc-12 g++-12 gcc-12-plugin-dev make cmake \
        libconfig++-dev lnav libsqlite3-dev libcurlpp-dev gdb wget curl ca-certificates \
        libcurl4-openssl-dev libboost-dev libboost-program-options-dev libboost-system-dev \
        libboost-filesystem-dev liblog4cxx-dev libboost-date-time-dev \
        librtmp-dev libnghttp2-dev libkrb5-dev comerr-dev libpsl-dev libssh-dev libbrotli-dev \
        libmysqlclient-dev libmysqlcppconn-dev net-tools iproute2 vim less dos2unix && \
    ODB_BUILD=/var/cache/nebbie-odb-build /usr/local/sbin/install-odb-toolchain.sh && \
    adduser --disabled-password --gecos "" vagrant && \
    usermod -aG sudo vagrant && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 90 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 90

RUN install -d -o vagrant -g vagrant /home/vagrant/Confs && \
    su - vagrant -c 'git config --global user.email "nebbie@hexkeep.com"' && \
    su - vagrant -c 'git config --global user.name "Nebbie Server"'

WORKDIR /app

FROM base AS build-env

USER vagrant
ENTRYPOINT ["/app/build.sh"]
CMD ["vagrant"]

FROM base AS builder

COPY . /app
RUN chown -R vagrant:vagrant /app

USER vagrant
RUN /app/build.sh vagrant

FROM base AS runtime

USER root

RUN echo "mysql-server mysql-server/root_password password secret" | debconf-set-selections && \
    echo "mysql-server mysql-server/root_password_again password secret" | debconf-set-selections && \
    apt-get update && \
    apt-get install -y mysql-server mysql-client apache2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app /app
RUN chown -R vagrant:vagrant /app

COPY sirio_dockers/docker-entrypoint.sh /usr/local/bin/
RUN dos2unix /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /app
EXPOSE 4003

USER root
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []
