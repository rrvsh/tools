#!/usr/bin/env bash
# Test script for yazi path-from-root plugin
# Usage: ./scripts/test-yazi-plugin.sh

set -e

PLUGIN_DIR="$HOME/.config/yazi/plugins/path-from-root.yazi"
KEYMAP_FILE="$HOME/.config/yazi/keymap.toml"

echo "=== Yazi Plugin Test Script ==="
echo ""

# Test 1: Check plugin directory exists
echo "Test 1: Plugin directory exists"
if [ -d "$PLUGIN_DIR" ]; then
    echo "  ✓ Plugin directory found: $PLUGIN_DIR"
else
    echo "  ✗ Plugin directory NOT found"
    exit 1
fi

# Test 2: Check main.lua exists (NOT init.lua)
echo ""
echo "Test 2: main.lua exists (Yazi expects main.lua)"
if [ -f "$PLUGIN_DIR/main.lua" ]; then
    echo "  ✓ main.lua found"
else
    echo "  ✗ main.lua NOT found"
    if [ -f "$PLUGIN_DIR/init.lua" ]; then
        echo "  ⚠ WARNING: init.lua exists instead - this won't work!"
    fi
    exit 1
fi

# Test 3: Check keymap.toml exists
echo ""
echo "Test 3: keymap.toml exists"
if [ -f "$KEYMAP_FILE" ]; then
    echo "  ✓ keymap.toml found"
else
    echo "  ✗ keymap.toml NOT found"
    exit 1
fi

# Test 4: Check keymap contains our plugin
echo ""
echo "Test 4: Keymap configuration"
if grep -q "plugin path-from-root" "$KEYMAP_FILE"; then
    echo "  ✓ Plugin keybinding found in keymap.toml"
else
    echo "  ✗ Plugin keybinding NOT found"
    exit 1
fi

# Test 5: Check plugin has entry function
echo ""
echo "Test 5: Plugin structure"
if grep -q "entry.*function" "$PLUGIN_DIR/main.lua"; then
    echo "  ✓ Plugin has entry function"
else
    echo "  ✗ Plugin missing entry function"
    exit 1
fi

# Test 6: Check ya command works
echo ""
echo "Test 6: Yazi CLI availability"
if command -v yazi &> /dev/null; then
    YAZI_VERSION=$(yazi --version 2>&1 | head -1)
    echo "  ✓ Yazi found: $YAZI_VERSION"
else
    echo "  ✗ Yazi NOT found in PATH"
    exit 1
fi

# Test 7: Check if in a git repo
echo ""
echo "Test 7: Git repository check"
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_ROOT=$(git rev-parse --show-toplevel)
    echo "  ✓ Inside git repo: $GIT_ROOT"
    
    # Test git commands the plugin uses
    echo ""
    echo "Test 8: Git commands plugin uses"
    if git rev-parse --show-toplevel > /dev/null 2>&1; then
        echo "  ✓ git rev-parse --show-toplevel works"
    else
        echo "  ✗ git rev-parse --show-toplevel failed"
    fi
    
    if git rev-parse --show-prefix > /dev/null 2>&1; then
        echo "  ✓ git rev-parse --show-prefix works"
    else
        echo "  ✗ git rev-parse --show-prefix failed"
    fi
else
    echo "  ⚠ Not in a git repo (plugin requires git repo to work)"
fi

echo ""
echo "=== All tests passed ==="
echo ""
echo "To manually test:"
echo "1. cd to a git repository"
echo "2. Run: yazi"
echo "3. Hover over a file"
echo "4. Press 'c' then 'r'"
echo "5. Check clipboard: pbpaste"
echo ""
echo "If the plugin still doesn't work, check yazi logs:"
echo "  ~/.local/state/yazi/yazi.log"
