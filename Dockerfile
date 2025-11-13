# Usa una base Linux moderna e leggera (ARM64 compatibile nativamente su M1)
FROM ubuntu:22.04

# Imposta variabili d'ambiente per evitare problemi con i prompt interattivi
ENV DEBIAN_FRONTEND=noninteractive

# Installa tutte le dipendenze: Compilatore C++, CMake, Git, Boost e ODB/MySQL
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        git \
        libboost-all-dev \
        libmysqlclient-dev \
        libodb-mysql-dev \
        wget \
        telnet \
        nano \
        vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Imposta la directory di lavoro all'interno del container, mappata alla cartella locale
WORKDIR /app

# Comando predefinito per mantenere il container in esecuzione in ambiente di sviluppo
CMD ["/bin/bash"]