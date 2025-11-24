# syntax=docker/dockerfile:1
FROM python:3.12-bookworm

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# System dependencies: build toolchain, debuggers, CMake, Ninja, Boost, etc.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc g++ \
        clang \
        gdb lldb \
        valgrind \
        cmake \
        ninja-build \
        git \
        pkg-config \
        python3-dev \
        libboost-all-dev \
        zlib1g-dev \
        autoconf \
        automake \
        libtool \
        bison \
        flex \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
COPY requirements.txt /app/requirements.txt
RUN python -m pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Install Limbo (includes Lemon as third party)
# Limbo is required for LEF/DEF parsers, GDSII parsers, and other utilities
# Note: Using latest version for simplicity. For production, consider pinning to a specific commit or tag.
RUN mkdir -p /opt/limbo && \
    cd /tmp && \
    git clone --depth 1 https://github.com/limbo018/Limbo.git && \
    cd Limbo && \
    mkdir -p build && \
    cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/opt/limbo \
        -DCMAKE_BUILD_TYPE=Release \
        -DOPENBLAS=OFF \
        -DINSTALL_LIMBO=ON && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf Limbo

# Install SparseHash
# SparseHash provides memory-efficient hash map implementations
# Note: Using latest version for simplicity. For production, consider pinning to a specific commit or tag.
RUN mkdir -p /opt/sparsehash && \
    cd /tmp && \
    git clone --depth 1 https://github.com/sparsehash/sparsehash.git && \
    cd sparsehash && \
    ./configure --prefix=/opt/sparsehash && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    rm -rf sparsehash

# Set environment variables for dependencies
# Note: Lemon is installed as part of Limbo at /opt/limbo/include/lemon
ENV LIMBO_DIR=/opt/limbo \
    LEMON_DIR=/opt/limbo \
    SPARSE_HASH_DIR=/opt/sparsehash

# Create non-root user for development/debugging
# Using UID/GID 1000 to match common host user IDs and avoid permission issues with mounted volumes
RUN useradd -ms /bin/bash -u 1000 -U dev
USER dev
WORKDIR /app

# Copy project (CLion will usually override with a bind mount)
COPY --chown=dev:dev . /app

ENV PYTHONPATH=/app \
    CC=/usr/bin/gcc \
    CXX=/usr/bin/g++ \
    CMAKE_GENERATOR=Ninja \
    PIP_NO_CACHE_DIR=1

CMD ["/bin/bash"]
