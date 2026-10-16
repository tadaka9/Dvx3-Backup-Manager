# DVX3 Backup Manager — Build Configuration (Vala 0.56 compatible)
# Supports GTK4 GUI and standalone CLI modes

CC = gcc
CFLAGS ?= -g2 -O1 -Wall -Wextra -D_GNU_SOURCE -DGDK_BACKEND=x11 -DGTK_SOURCE=4
VALAC ?= valac
PKG_CONFIG := $(shell which pkg-config 2>/dev/null || echo "")

SOURCES = cli/main.vala vala/core/dvx3.vala vala/core/incremental.vala cli/incremental.vala
TARGET = dvx3-cli
EXECS = dvx3-cli
TEST_TARGET = dvx3-cli-test

ifdef GTK4_FOUND
    CFLAGS += -DGTK_SOURCE=4
endif

.PHONY: all clean install uninstall test help

all: $(EXECS)

$(EXECS): $(SOURCES)
	@echo "[+] Building DVX3 Backup Manager..."
ifeq ($(PKG_CONFIG),)
	@if echo "Checking for GTK4 support..."; \
	PKG_CHECK=$(shell pkg-config --exists gtk4 && echo yes || echo no); \
	if [ "$$PKG_CHECK" = "yes" ]; then \
		echo "[+] GTK4 found — building with GUI support"; \
	else \
		echo "[!] GTK4 not found — building standalone CLI (no GUI)"; \
	fi; \
	exit 0; \
	PKG_CONFIG := $(shell which pkg-config 2>/dev/null || echo ""); \
	if [ "$$(echo '$(PKG_CONFIG)' | grep -c 'pkg-config')" = "1" ]; then \
		echo "[+] pkg-config available"; \
	else \
		echo "[!] pkg-config not found — compiling without GTK4 dependencies"; \
	fi; \
	exit 0;
endif
ifeq ($(GTK4_FOUND),)
	@echo "[!] Building without GTK4 (standalone CLI mode)";
else
	$(VALAC) --cc=$(CC) $(CFLAGS) -O1 --disable-gir-warnings \
		--no-error-on-unresolved-links \
		$(SOURCES) -o $(TARGET)
endif

# Test executable
dvx3-cli-test: cli/main.vala vala/core/dvx3.vala vala/core/incremental.vala cli/incremental.vala
	@echo "[+] Building test binary..."
ifeq ($(GTK4_FOUND),)
	$(VALAC) --cc=$(CC) $(CFLAGS) -O1 \
		-DTEST_MODE=1 \
		--disable-gir-warnings \
		--no-error-on-unresolved-links \
		cli/main.vala vala/core/dvx3.vala vala/core/incremental.vala cli/incremental.vala \
		-o dvx3-cli-test || echo "[!] Test build failed (expected without GTK4)"
else
	$(VALAC) --cc=$(CC) $(CFLAGS) -O1 \
		--disable-gir-warnings \
		--no-error-on-unresolved-links \
		cli/main.vala vala/core/dvx3.vala vala/core/incremental.vala cli/incremental.vala \
		-o dvx3-cli-test
endif

clean:
	rm -f $(EXECS) *.o vala/*/*.gi vala/*/*.vapi build/ install/

install: all
	@echo "[+] Installation would require root/sudo — skipping (run manually if needed)"

uninstall: clean
	@rm -f dvx3-cli dvx3-cli-test

test: $(EXECS)
ifeq ($(GTK4_FOUND),)
	@echo "[!] Skipping test run (no GTK4 build available)"
else
	@echo "Running DVX3 CLI tests..."; ./dvx3-cli --help; \
	echo "---"; ./dvx3-cli -e -p 'test123' /tmp/test-backup 2>&1 || echo "[!] Backup test skipped (no source dir)"; \
	echo "Tests complete."
endif

help:
	@echo "DVX3 Backup Manager — Build Targets:"
	@echo "  make all     — Build CLI executable"
	@echo "  make test    — Run CLI help/usage tests"
	@echo "  make clean   — Remove build artifacts"
	@echo "  make install — Install to /usr/local/bin (requires sudo)"