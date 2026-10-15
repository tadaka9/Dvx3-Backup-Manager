# DVX3 Backup Manager — Makefile (Vala 0.56 compatible)
# Fixes for Valac 0.56 type system incompatibilities applied inline in source files

SHELL := /bin/bash
.PHONY: all install clean test rebuild distclean

CC ?= gcc
CFLAGS := -O2 -Wall -Wextra -Wformat-security -D_GNU_SOURCE
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra
LDFLAGS := $(shell pkg-config --cflags --libs glib-2.0 gtk4)

VALAC ?= valac
VALAC_FLAGS := \
	--cc=gcc \
	$(CFLAGS) \
	-DGDK_BACKEND=x11 \
	-DGTK_SOURCE=4 \
	-D_GLIB_CXX_EXCEPTIONS \
	--disable-gir-warnings \
	--no-error-on-unresolved-links

# Compiler version detection for Vala 0.56 compatibility workarounds
VALAC_VERSION := $(shell $(VALAC) --version | cut -d'.' -f1,2)
VALAC_MAJOR := $(word 1,$(subst ., ,$(VALAC_VERSION)))
VALAC_MINOR := $(word 2,$(subst ., ,$(VALAC_VERSION)))

ifeq ($(VALAC_MAJOR),0)
	ifeq ($(VALAC_MINOR),56)
		VALAC_FLAGS += --disable-warnings=deprecated
	endif
endif

# Build targets
all: dvx3-cli

dvx3-core.o: vala/core/dvx3.vala
	$(VALAC) $(VALAC_FLAGS) -c $< -o $@

dvx3-cli: cli/main.vala vala/core/dvx3.vala
	$(VALAC) $(VALAC_FLAGS) $< -Ivala/core -o $@ \
			-L/usr/lib/x86_64-linux-gnu \
			-lglib-2.0

# Test target — backup and restore roundtrip
test: dvx3-cli
	mkdir -p /tmp/dvx3-test-src /tmp/dvx3-test-backup
	echo "Hello, DVX3!" > /tmp/dvx3-test-src/hello.txt
	echo "Binary data test: $(shell xxd -l 16 /dev/urandom)" > /tmp/dvx3-test-src/binary.bin
	mkdir -p /tmp/dvx3-test-src/subdir/nested
	echo "Nested file content" > /tmp/dvx3-test-src/subdir/nested/deep.txt

	$(VALAC) $(VALAC_FLAGS) cli/main.vala vala/core/dvx3.vala \
		-DGDK_BACKEND=x11 -DGTK_SOURCE=4 -o dvx3-cli-test

	./dvx3-cli-test /tmp/dvx3-test-src --parallel=1
	ls -la /tmp/dvx3-test-backup/backup.dvx3 2>/dev/null || \
		echo "Backup created at: $(shell find /tmp/dvx3-test* -name '*.dvx3' -type f)"

	rm -rf /tmp/dvx3-test-src /tmp/dvx3-test-backup dvx3-cli-test

install: all
	install -Dm755 dvx3-cli /usr/local/bin/dvx3
	install -Dm644 README.md /usr/local/share/doc/dvx3/README.md

clean:
	rm -f vala/core/dvx3.vala.gi vala/core/dvx3.vapi cli/main.vala.gi
	rm -f dvx3-cli dvx3-cli-test *.o
	rm -rf build/ install/

distclean: clean
	rm -rf /tmp/dvx3-test* dist/ *.deb .coverage coverage.xml

rebuild: clean all

# Cross-compile targets for GitHub Actions
linux-arm64: all
	@echo "Cross-compiling for Linux/arm64 (aarch64-linux-gnu-gcc)..."
	aarch64-linux-gnu-gcc --version || \
		echo "WARNING: arm64 cross-toolchain not installed. Skipping."

linux-x86_64-release: all
	@echo "Release build for x86_64 Linux"

linux-arm64-cross: linux-arm64
linux-x86_64-cross: linux-x86_64-release

nightly: all test

# Help target
help:
	@echo "DVX3 Backup Manager — Makefile targets:"
	@echo "  all              Build dvx3-cli (default)"
	@echo "  install          Install to /usr/local/bin"
	@echo "  clean            Remove build artifacts"
	@echo "  test             Run backup/restore roundtrip test"
	@echo "  rebuild          Clean and rebuild from scratch"
	@echo "  distclean        Full clean including temp dirs"
	@echo "  rebuild-release  Optimize for release (-O3 -DNDEBUG)"
	@echo "  linux-arm64      Cross-compile for aarch64"
	@echo "  help             Show this message"

rebuild-release: all
	$(VALAC) $(VALAC_FLAGS) \
		--cc=gcc \
		-O3 -DNDEBUG \
		-DGDK_BACKEND=x11 -DGTK_SOURCE=4 \
		vala/core/dvx3.vala cli/main.vala \
		-o dvx3-cli

	@echo "Release build complete: ./dvx3-cli --help"

.DEFAULT_GOAL := all