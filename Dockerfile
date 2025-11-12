# Stage 1: Builder
# This stage installs all build dependencies and compiles the application.
FROM debian:trixie AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    pkg-config \
    valac \
    libglib2.0-dev \
    libjson-glib-dev \
    libsodium-dev \
    qt6-base-dev \
    qt6-tools-dev

# Set the working directory
WORKDIR /app

# Copy the entire project source code into the container
COPY . .

# Make build scripts executable
RUN chmod +x ./*.sh

# Run the build script for the GUI
# This will compile the Vala code, C++ code, and the Qt GUI
RUN ./build_gui.sh

# Stage 2: Final Image
# This stage takes only the compiled application and its runtime dependencies.
FROM debian:trixie-slim

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libjson-glib-1.0-0 \
    libsodium23 \
    libqt6widgets6 \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /usr/bin

# Copy the compiled application and the shared library from the builder stage
COPY --from=builder /app/backup-manager-gui .
COPY --from=builder /app/libdvx3.so /usr/lib/

# Set the command to run the application
CMD ["/usr/bin/backup-manager-gui"]
