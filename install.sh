#!/bin/bash

# Dotfiles install script
# Creates symlinks for all configs and scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing dotfiles...${NC}\n"

# Link bin scripts
if [[ -d "$SCRIPT_DIR/bin" ]]; then
    echo "Installing scripts..."
    mkdir -p ~/.local/bin

    for script in "$SCRIPT_DIR"/bin/*; do
        if [[ -f "$script" && -x "$script" ]]; then
            name=$(basename "$script")
            target="$HOME/.local/bin/$name"

            if [[ -L "$target" ]]; then
                rm "$target"
            fi

            ln -sf "$script" "$target"
            echo -e "  ${GREEN}✓${NC} $name"
        fi
    done
fi

echo ""
echo -e "${GREEN}Done!${NC}"
