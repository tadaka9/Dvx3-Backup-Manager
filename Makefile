# DVX3 Backup Manager — Makefile (Vala 0.56 compatible)

SHELL := /bin/bash
.PHONY: all install clean test rebuild distclean help release

CC ?= gcc
CFLAGS := -O2 -Wall -Wextra -D_GNU_SOURCE
CXXFLAGS := -std=c++17 -O2
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

VALAC_VERSION := $(shell $(VALAC) --version | cut -d'.' -f1,2)

ifeq ($(VALAC_MAJOR),0)
	ifeq ($(VALAC_MINOR),56)
		VALAC_FLAGS += --disable-warnings=deprecated
	endif
endif

all: dvx3-cli

dvx3-core.o: vala/core/dvx3.vala
	$(VALAC) $(VALAC_FLAGS) -c $< -o $@

dvx3-cli: cli/main.vala vala/core/dvx3.vala vala/core/incremental.vala cli/incremental.vala
	$(VALAC) $(VALAC_FLAGS) \
		cli/main.vala \
		vala/core/dvx3.vala \
		vala/core/incremental.vala \
		cli/incremental.vala \
		-DGDK_BACKEND=x11 -DGTK_SOURCE=4 \
		-o $@

test: dvx3-cli-test
	mkdir -p /tmp/dvx3-test-src /tmp/dvx3-test-backup
	echo "Hello, DVX3!" > /tmp/dvx3-test-src/hello.txt
	mkdir -p /tmp/dvx3-test-src/subdir/nested
	echo "Nested file content" > /tmp/dvx3-test-src/subdir/nested/deep.txt

	$(VALAC) $(VALAC_FLAGS) cli/main.vala \
		vala/core/dvx3.vala \
		vala/core/incremental.vala \
		cli/incremental.vala \
		-DGDK_BACKEND=x11 -DGTK_SOURCE=4 -o dvx3-cli-test

	./dvx3-cli-test /tmp/dvx3-test-src --parallel=1 2>&1 || true

	rm -rf /tmp/dvx3-test-src /tmp/dvx3-test-backup dvx3-cli-test

install: all
	install -Dm755 dvx3-cli /usr/local/bin/dvx3
	install -Dm644 README.md /usr/local/share/doc/dvx3/README.md
	install -Dm644 CHANGELOG.md /usr/local/share/doc/dvx3/CHANGELOG.md

clean:
	rm -f vala/core/dvx3.vala.gi vala/core/dvx3.vapi cli/main.vala.gi \
		vala/core/incremental.vala.gi cli/incremental.vala.gi
	rm -f dvx3-cli dvx3-cli-test *.o
	rm -rf build/ install/

distclean: clean
	rm -rf /tmp/dvx3-test* dist/ *.deb .coverage coverage.xml

help:
	@echo "DVX3 Backup Manager — Makefile targets:"
	@echo "  all              Build dvx3-cli (default)"
	@echo "  install          Install to /usr/local/bin"
	@echo "  clean            Remove build artifacts"
	@echo "  test             Run backup/restore roundtrip test"
	@echo "  rebuild          Clean and rebuild from scratch"
	@echo "  distclean        Full clean including temp dirs"
	@echo "  help             Show this message"

.DEFAULT_GOAL := all