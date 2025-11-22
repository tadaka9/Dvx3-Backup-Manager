#!/bin/bash
# fix_line_endings.sh - Convert build_gui.sh to Unix-style LF line endings

if [[ ! -f build_gui.sh ]]; then
  echo "Error: build_gui.sh not found in current directory."
  exit 1
fi

echo "Converting build_gui.sh to Unix-style LF line endings..."
sed -i 's/\r$//' build_gui.sh
echo "Conversion complete."
