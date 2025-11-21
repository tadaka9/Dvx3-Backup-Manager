# Use a lightweight base with recent libraries
FROM debian:bookworm-slim

# Install runtime dependencies
# (We install build deps, build, then remove build deps to keep image small)
RUN apt-get update && apt-get install -y \
    valac \
    build-essential \
    libglib2.0-dev \
    libjson-glib-dev \
    libsodium-dev \
    zstd \
    qt6-base-dev \
    qt6-base-dev-tools \