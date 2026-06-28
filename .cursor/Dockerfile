# Immagine base per Cursor Cloud Agents — repo Nebbie Server
# Non copiare il progetto: Cursor fa checkout del commit in workspace.
FROM ubuntu:24.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    sudo \
    sshpass \
    openssh-client \
    ca-certificates \
    curl \
    build-essential \
    cmake \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*
