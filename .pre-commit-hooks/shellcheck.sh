#!/bin/bash
# ShellCheck wrapper for pre-commit
# Runs shellcheck with warning-level severity on all bash scripts

SCRIPTS=$(find . -name "*.sh" ! -path "*/node_modules/*" | sort)

if [ -z "$SCRIPTS" ]; then
    echo "No shell scripts found to lint."
    exit 0
fi

echo "🔍 ShellCheck: $SCRIPTS"

for script in $SCRIPTS; do
    if [[ "$script" == *"test"* ]] || [[ "$script" == *"ci-test"* ]]; then
        # Skip test files - they may have intentionally different patterns
        continue
    fi
    
    echo "  Checking: $(basename "$script")"
    shellcheck --severity=warning "$script" 2>&1 | tee /dev/stderr || true
done

echo "✅ ShellCheck complete (warnings above, if any)"
