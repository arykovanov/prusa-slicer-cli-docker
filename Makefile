# Makefile to build PrusaSlicer without Docker on Ubuntu

# Directories
SRC_DIR = $(CURDIR)/src
DEPS_BUILD_DIR = $(CURDIR)/build/deps
APP_BUILD_DIR = $(CURDIR)/build/app
DEP_DOWNLOAD_DIR = $(CURDIR)/build/deps-downloads
INSTALL_DIR = $(CURDIR)/build/install

# Build configuration
BUILD_TYPE = Release

# Number of parallel jobs
NPROC = $(shell nproc)

# Number of parallel linker jobs to limit memory usage
LINK_JOBS = 1

.PHONY: all install_deps build_deps build_app install clean

all: build_deps build_app

install_deps:
	sudo apt-get update && sudo apt-get install -y --no-install-recommends \
		git \
		build-essential \
		autoconf \
		automake \
		libtool \
		cmake \
		ninja-build \
		pkg-config \
		libglu1-mesa-dev \
		libdbus-1-dev \
		texinfo \
		curl \
		wget \
		unzip \
		zip \
		libsecret-1-dev \
		libssl-dev \
		ca-certificates \
		libpng-dev \
		libexpat1-dev \
		zlib1g-dev \
		libbz2-dev \
		liblzma-dev \
		locales

build_deps:
	mkdir -p $(DEP_DOWNLOAD_DIR)
	mkdir -p $(DEPS_BUILD_DIR)
	cd $(DEPS_BUILD_DIR) && \
		cmake $(SRC_DIR)/deps \
			-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
			-DDEP_DOWNLOAD_DIR=$(DEP_DOWNLOAD_DIR) \
			-DPrusaSlicer_deps_PACKAGE_EXCLUDES="wxWidgets|OpenCSG|Catch2"
	$(MAKE) -C $(DEPS_BUILD_DIR) -j$$(( $(NPROC) / 2 ))

build_app:
	mkdir -p $(APP_BUILD_DIR)
	cd $(APP_BUILD_DIR) && \
		cmake $(SRC_DIR) -GNinja \
			-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
			-DSLIC3R_STATIC=ON \
			-DSLIC3R_GUI=OFF \
			-DSLIC3R_PCH=OFF \
			-DSLIC3R_FHS=ON \
			-DSLIC3R_BUILD_TESTS=OFF \
			-DCMAKE_JOB_POOLS="link_pool=$(LINK_JOBS)" \
			-DCMAKE_JOB_POOL_LINK=link_pool \
			-DCMAKE_INSTALL_PREFIX=/usr \
			-DCMAKE_PREFIX_PATH=$(DEPS_BUILD_DIR)/destdir/usr/local
	ninja -C $(APP_BUILD_DIR) -j$$(( $(NPROC) / 2 ))

install:
	mkdir -p $(DESTDIR)/usr/bin
	install -m 755 $(APP_BUILD_DIR)/src/prusa-slicer $(DESTDIR)/usr/bin/prusa-slicer
	ln -sf prusa-slicer $(DESTDIR)/usr/bin/prusa-gcodeviewer

clean:
	rm -rf $(DEPS_BUILD_DIR) $(APP_BUILD_DIR) $(INSTALL_DIR)
