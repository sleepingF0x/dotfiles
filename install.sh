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

# Link shell aliases
if [[ -f "$SCRIPT_DIR/aliases" ]]; then
    echo ""
    echo "Installing shell aliases..."

    ALIASES_SOURCE="$SCRIPT_DIR/aliases"
    ALIASES_TARGET="$HOME/.aliases"
    CURRENT_TARGET=""

    if [[ -L "$ALIASES_TARGET" ]]; then
        CURRENT_TARGET="$(readlink "$ALIASES_TARGET")"
    fi

    if [[ -e "$ALIASES_TARGET" || -L "$ALIASES_TARGET" ]] && [[ "$CURRENT_TARGET" != "$ALIASES_SOURCE" ]]; then
        BACKUP_TARGET="$ALIASES_TARGET.backup.$(date +%Y%m%d%H%M%S)"
        mv "$ALIASES_TARGET" "$BACKUP_TARGET"
        echo -e "  ${GREEN}✓${NC} backed up existing ~/.aliases to $(basename "$BACKUP_TARGET")"
    fi

    ln -sf "$ALIASES_SOURCE" "$ALIASES_TARGET"
    echo -e "  ${GREEN}✓${NC} ~/.aliases"

    # Ensure shell rc files source ~/.aliases
    SOURCE_LINE='[ -f "$HOME/.aliases" ] && . "$HOME/.aliases"'
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [[ -f "$rc" ]] && ! grep -Fq "$SOURCE_LINE" "$rc"; then
            printf '\n# Load shared aliases from dotfiles\n%s\n' "$SOURCE_LINE" >> "$rc"
            echo -e "  ${GREEN}✓${NC} sourced in $(basename "$rc")"
        fi
    done
fi

# Ensure secrets env file exists and is sourced
ENV_DIR="$HOME/.config/secrets"
ENV_TARGET="$ENV_DIR/env.sh"
ENV_SOURCE_LINE='[ -f "$HOME/.config/secrets/env.sh" ] && . "$HOME/.config/secrets/env.sh"'


echo ""
echo "Installing secrets env..."
mkdir -p "$ENV_DIR"

if [[ -f "$ENV_TARGET" ]]; then
    echo -e "  ${GREEN}✓${NC} ~/.config/secrets/env.sh already exists"
else
    : > "$ENV_TARGET"
    echo -e "  ${GREEN}✓${NC} created ~/.config/secrets/env.sh"
fi

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$rc" ]]; then
        if grep -Fq "$ENV_SOURCE_LINE" "$rc"; then
            echo -e "  ${GREEN}✓${NC} env.sh already sourced in $(basename "$rc")"
        else
            printf '\n# Load secrets environment\n%s\n' "$ENV_SOURCE_LINE" >> "$rc"
            echo -e "  ${GREEN}✓${NC} sourced env.sh in $(basename "$rc")"
        fi
    fi
done

echo ""
echo -e "${GREEN}Done!${NC}"
