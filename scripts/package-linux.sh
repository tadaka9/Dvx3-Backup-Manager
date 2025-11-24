#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

RELEASE_DIR="Releases/linux"
LIB_DIR="$RELEASE_DIR/lib"

mkdir -p "$RELEASE_DIR" "$LIB_DIR"

copy_if_exists() {
  if [ -f "$1" ]; then
    cp -v "$1" "$RELEASE_DIR/"
  fi
}

copy_binary_deps() {
  local bin="$1"
  echo "Scanning deps for $bin"
  ldd "$bin" 2>/dev/null | grep '=> /' | awk '{print $3}' | while read -r lib; do
    [[ -f "$lib" ]] || continue
    local libname
    libname=$(basename "$lib")
    case "$libname" in
      libc.so*|libm.so*|libpthread.so*|librt.so*|libdl.so*|ld-linux*|libgcc_s*|libstdc++.so*|libc-2.*)
        # skip core system libs
        continue
        ;;
    esac
    # Exclude some system libraries which are not portable or expected to be present on target
    EXCLUDE_LIBS=(libsystemd.so libcap.so libgomp.so libmount.so libpthread.so.0)
    for e in "${EXCLUDE_LIBS[@]}"; do
      if [[ "$libname" == $e* ]]; then
        echo "Skipping system lib $libname"
        continue 2
      fi
    done
    if [ ! -e "$LIB_DIR/$libname" ]; then
      echo "Copying $libname"
      cp -v "$lib" "$LIB_DIR/"
    fi
  done
}

echo "Packaging Linux binaries into $RELEASE_DIR"
copy_if_exists backup-manager-gui
copy_if_exists backup-manager
copy_if_exists dvx3
copy_if_exists libdvx3.so

# Also copy extra files (icon) if present
# Also copy icon if present
if [ -f dvx3-backup.png ]; then
  cp -v dvx3-backup.png "$RELEASE_DIR/"
fi

# Copy deps for each binary
for bin in "backup-manager-gui" "backup-manager" "dvx3"; do
  if [ -f "$bin" ]; then
    copy_binary_deps "$bin"
  fi
done

# Create a run wrapper for the GUI so users can launch it using the bundled libs
cat > "$RELEASE_DIR/run-gui.sh" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/backup-manager-gui" "$@"
EOF
chmod +x "$RELEASE_DIR/run-gui.sh"

# Create CLI wrappers to use bundled libs for the CLI binaries
cat > "$RELEASE_DIR/run-dvx3.sh" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/dvx3" "$@"
EOF
chmod +x "$RELEASE_DIR/run-dvx3.sh"

cat > "$RELEASE_DIR/run-backup-manager.sh" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/backup-manager" "$@"
EOF
chmod +x "$RELEASE_DIR/run-backup-manager.sh"

# Create compressed tarball for Releases/linux for convenience
mkdir -p "$(dirname "$RELEASE_DIR")"
tar -C "$(dirname "$RELEASE_DIR")" -czf Releases/Dvx3-Backup-Manager-Linux.tar.gz "$(basename "$RELEASE_DIR")"

echo "Packaging complete. Releases available at $RELEASE_DIR"

# Create top-level run wrapper for Releases/ that delegates to the packaged linux wrappers
TOP_RUN="Releases/run.sh"
cat > "$TOP_RUN" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
if [ -x "$HERE/linux/run-gui.sh" ]; then
  exec "$HERE/linux/run-gui.sh" "$@"
else
  echo "No Linux package found in $HERE/linux" >&2
  exit 1
fi
EOF
chmod +x "$TOP_RUN"

echo "Created top-level wrapper: $TOP_RUN"
