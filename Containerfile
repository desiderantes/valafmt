# Multi-stage Containerfile for valafmt
# Based on Ubuntu 26.04

# Stage 1: Build environment
FROM ubuntu:26.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    git \
    meson \
    ninja-build \
    pkg-config \
    valac \
    libtree-sitter-dev \
    nodejs \
    tree-sitter-cli \
    libglib2.0-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN meson setup build --buildtype=release && \
    ninja -C build && \
    meson test -C build && \
    ninja -C build install

# Stage 2: Minimal runtime image
FROM ubuntu:26.04 AS runner

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0t64 \
    libtree-sitter0.25 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/valafmt /usr/local/bin/valafmt

WORKDIR /code

ENTRYPOINT ["/usr/local/bin/valafmt"]
CMD ["--help"]
