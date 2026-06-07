# Base image to override to a custom registry
ARG BASE_IMAGE=ubuntu:24.04
# Version of PrusaSlicer to clone and build (can be a tag or branch name)
ARG PRUSASLICER_VERSION=version_2.9.5

# ==============================================================================
# Builder Stage
# ==============================================================================
FROM ${BASE_IMAGE} AS builder

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install make, git, ca-certificates, sudo, and locales
RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    git \
    ca-certificates \
    sudo \
    locales

# Generate locale to avoid warnings and potential encoding issues
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Set up working directory
WORKDIR /app

# Copy the Makefile to the builder stage
COPY Makefile /app/Makefile

# Install all build dependencies using the Makefile target
RUN make install_deps

# Clone the repository directly inside the image under /app/src
RUN git clone https://github.com/arykovanov/PrusaSlicer.git /app/src && \
    cd /app/src && \
    git checkout ${PRUSASLICER_VERSION}

# Build dependencies using the Makefile
RUN --mount=type=cache,target=/deps-downloads \
    make build_deps DEP_DOWNLOAD_DIR=/deps-downloads

# Build PrusaSlicer itself using the Makefile
RUN make build_app && make install DESTDIR=/app/build/install

# ==============================================================================
# Runner Stage
# ==============================================================================
FROM ${BASE_IMAGE}

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install minimal runtime libraries required by the console version of PrusaSlicer
RUN apt-get update && apt-get install -y --no-install-recommends \
    libdbus-1-3 \
    libcurl4 \
    libsecret-1-0 \
    libpng16-16t64 \
    ca-certificates \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Generate locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Copy build artifacts from builder stage
COPY --from=builder /app/build/install/ /

# Define entrypoint to run the console prusa-slicer
ENTRYPOINT ["prusa-slicer"]
CMD ["--help"]
