#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--prefix <QT6_PREFIX>] [--verbose]

Checks for Qt6 'moc' and 'rcc' binaries and prints helpful diagnostics.

Options:
  --prefix <path>   Use the provided prefix as QT6_PREFIX (e.g. /opt/homebrew/opt/qt)
  --verbose         Print extra diagnostics
  -h, --help         Show this help
EOF
}

QT6_PREFIX="${QT6_PREFIX:-}"
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) QT6_PREFIX="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1"; usage; exit 2 ;;
  esac
done

echo "=== QT Detection Helper ==="
echo "OS: $(uname -s) $(uname -m)"
echo "QT6_PREFIX (env/arg): ${QT6_PREFIX:-'(none)'}"

if command -v brew >/dev/null 2>&1; then
  echo "Homebrew available: $(brew --version | head -n1)"
  # Find an installed Qt formula, prefer qt@6, then qt, then qt6
  if [ -z "$QT6_PREFIX" ]; then
    if brew ls --versions qt@6 >/dev/null 2>&1; then
      QT6_FORMULA=qt@6
    elif brew ls --versions qt >/dev/null 2>&1; then
      QT6_FORMULA=qt
    elif brew ls --versions qt6 >/dev/null 2>&1; then
      QT6_FORMULA=qt6
    else
      QT6_FORMULA=""
    fi
    if [ -n "$QT6_FORMULA" ]; then
      DETECTED_PREFIX=$(brew --prefix "$QT6_FORMULA" 2>/dev/null || true)
      if [ -n "$DETECTED_PREFIX" ]; then
        echo "Found Homebrew Qt formula: $QT6_FORMULA -> prefix: $DETECTED_PREFIX"
        QT6_PREFIX="$DETECTED_PREFIX"
      fi
    fi
  fi
fi

if [ -n "$QT6_PREFIX" ]; then
  echo "Using QT6_PREFIX: $QT6_PREFIX"
fi

echo "Checking common moc/rcc locations..."

declare -a MOC_PATHS
declare -a RCC_PATHS

# If user supplied QT6_PREFIX, prefer binaries under that prefix
if [ -n "$QT6_PREFIX" ]; then
  MOC_PATHS+=("$QT6_PREFIX/bin/moc" "$QT6_PREFIX/bin/moc-qt6")
  RCC_PATHS+=("$QT6_PREFIX/bin/rcc" "$QT6_PREFIX/bin/rcc-qt6")
fi

# macOS / Homebrew candidates
MOC_PATHS+=(
  "/opt/homebrew/opt/qt@6/bin/moc"
  "/opt/homebrew/opt/qt/bin/moc"
  "/opt/homebrew/opt/qt6/bin/moc"
  "/usr/local/opt/qt@6/bin/moc"
  "/usr/local/opt/qt/bin/moc"
  "/usr/local/opt/qt6/bin/moc"
  "/opt/homebrew/bin/moc"
  "/usr/local/bin/moc"
)

RCC_PATHS+=(
  "/opt/homebrew/opt/qt@6/bin/rcc"
  "/opt/homebrew/opt/qt/bin/rcc"
  "/opt/homebrew/opt/qt6/bin/rcc"
  "/usr/local/opt/qt@6/bin/rcc"
  "/usr/local/opt/qt/bin/rcc"
  "/usr/local/opt/qt6/bin/rcc"
  "/opt/homebrew/bin/rcc"
  "/usr/local/bin/rcc"
)

# Linux candidates
MOC_PATHS+=(
  "/usr/bin/moc"
  "/usr/lib/qt6/bin/moc"
  "/usr/lib/qt6/libexec/moc"
)
RCC_PATHS+=(
  "/usr/bin/rcc"
  "/usr/lib/qt6/bin/rcc"
  "/usr/lib/qt6/libexec/rcc"
)

# MSYS/MinGW candidates
MOC_PATHS+=(
  "/mingw64/bin/moc"
  "/mingw64/share/qt6/bin/moc"
  "/mingw64/lib/qt6/bin/moc"
  "/mingw64/qt6/bin/moc"
  "/mingw64/bin/moc-qt6"
  "/mingw64/bin/moc6"
)
RCC_PATHS+=(
  "/mingw64/bin/rcc"
  "/mingw64/share/qt6/bin/rcc"
  "/mingw64/lib/qt6/bin/rcc"
  "/mingw64/qt6/bin/rcc"
  "/mingw64/bin/rcc-qt6"
  "/mingw64/bin/rcc6"
)

echo
found_moc=0
found_rcc=0
for p in "${MOC_PATHS[@]}"; do
  if [ -x "$p" ]; then
    echo "OK  moc found: $p"
    found_moc=1
  elif [ -e "$p" ]; then
    echo "WARN moc exists but not executable: $p"
  else
    if [ "$VERBOSE" = "1" ]; then
      echo ".. moc candidate missing: $p"
    fi
  fi
done

for p in "${RCC_PATHS[@]}"; do
  if [ -x "$p" ]; then
    echo "OK  rcc found: $p"
    found_rcc=1
  elif [ -e "$p" ]; then
    echo "WARN rcc exists but not executable: $p"
  else
    if [ "$VERBOSE" = "1" ]; then
      echo ".. rcc candidate missing: $p"
    fi
  fi
done

echo
# Check which command-available variants exist
for cmd in moc moc-qt6 moc6 rcc rcc-qt6 rcc6 qmake qmake6; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "PATH: $(command -v $cmd) -> $($cmd --version 2>/dev/null || echo 'version unknown')"
  fi
done

if [ $found_moc -eq 1 ] || [ $found_rcc -eq 1 ]; then
  echo
  echo "SUCCESS: At least one of moc/rcc was found."
  echo "If you need a specific Qt6 install or path, set QT6_PREFIX, e.g.:"
  echo "  export QT6_PREFIX=\$(brew --prefix qt)"
  exit 0
else
  echo
  echo "ERROR: Unable to detect 'moc' or 'rcc' binaries."
  echo "Suggested fixes:"
  echo "  - Install Qt6 via Homebrew: 'brew install qt@6' or 'brew install qt'"
  echo "  - On macOS arm64 use: 'eval \"\$(/opt/homebrew/bin/brew shellenv)\"' then install"
  echo "  - Or set QT6_PREFIX to the proper prefix: 'export QT6_PREFIX=\$(brew --prefix qt)'"
  echo "  - Alternatively use your system package manager to provide Qt6 dev tools"
  exit 1
fi
