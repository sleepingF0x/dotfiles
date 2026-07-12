#!/bin/bash

# Dotfiles install script
# Creates symlinks for all configs and scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}Installing dotfiles...${NC}\n"

# Append a source line to each shell rc, unless that path is already sourced.
# Matching on the path (not the whole line) means an existing `source X` is
# recognised as equivalent to `. X`, so re-running never appends a duplicate.
ensure_sourced() {
    local needle="$1" comment="$2" line="$3" rc
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        [[ -f "$rc" ]] || continue
        grep -Fq "$needle" "$rc" && continue
        printf '\n%s\n%s\n' "$comment" "$line" >> "$rc"
        echo -e "  ${GREEN}✓${NC} sourced in $(basename "$rc")"
    done
}

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

    ensure_sourced '$HOME/.aliases' \
        '# Load shared aliases from dotfiles' \
        '[ -f "$HOME/.aliases" ] && . "$HOME/.aliases"'
fi

# Secrets environment
#
# Secret VALUES never enter this repo. Only the variable names do, via
# secrets.env.example, so a new machine knows what it still has to fill in.
#
#   dotfiles/secrets.env.example  -> tracked, names only
#   ~/.config/secrets/*.env       -> real values, chmod 600, never committed
#   ~/.config/secrets/env.sh      -> loader, sources every *.env above
ENV_DIR="$HOME/.config/secrets"
ENV_TARGET="$ENV_DIR/env.sh"
ENV_EXAMPLE="$SCRIPT_DIR/secrets.env.example"
LOADER_MARKER="dotfiles-secrets-loader"

echo ""
echo "Installing secrets env..."
mkdir -p "$ENV_DIR"
chmod 700 "$ENV_DIR"

# An env.sh without our marker is a hand-written file holding secrets inline.
# Preserve those values before overwriting it with the loader.
if [[ -f "$ENV_TARGET" ]] && ! grep -Fq "$LOADER_MARKER" "$ENV_TARGET"; then
    BACKUP="$ENV_TARGET.backup-$(date +%Y%m%d%H%M%S)"
    cp -p "$ENV_TARGET" "$BACKUP"
    echo -e "  ${GREEN}✓${NC} backed up hand-written env.sh to $(basename "$BACKUP")"

    if [[ ! -f "$ENV_DIR/secrets.env" ]]; then
        cp -p "$ENV_TARGET" "$ENV_DIR/secrets.env"
        chmod 600 "$ENV_DIR/secrets.env"
        echo -e "  ${GREEN}✓${NC} migrated its variables into secrets.env"
    fi
fi

cat > "$ENV_TARGET" <<'EOF_ENV_SH'
# dotfiles-secrets-loader v1
#
# Entrypoint sourced by ~/.zshrc / ~/.bashrc. Holds no secrets itself.
# Real values live in sibling *.env files (chmod 600, never committed):
#
#   ~/.config/secrets/secrets.env
#   ~/.config/secrets/some-project.env
#
# Variable names are tracked in dotfiles/secrets.env.example so a new machine
# knows what to fill in. Regenerate this loader by running dotfiles/install.sh.

_secrets_load() {
  _sd="$HOME/.config/secrets"
  [ -d "$_sd" ] || return 0

  # zsh aborts on an unmatched glob; make it expand to nothing instead.
  # bash/sh leave it literal, which the -r test below skips.
  if [ -n "${ZSH_VERSION:-}" ]; then
    setopt local_options null_glob
  fi

  for _f in "$_sd"/*.env; do
    [ -r "$_f" ] || continue
    set -a
    . "$_f"
    set +a
  done

  unset _sd _f
}

_secrets_load
unset -f _secrets_load
EOF_ENV_SH
chmod 600 "$ENV_TARGET"
echo -e "  ${GREEN}✓${NC} ~/.config/secrets/env.sh (loader)"

# Fresh machine with no values yet: seed secrets.env from the tracked template.
if [[ -f "$ENV_EXAMPLE" ]]; then
    shopt -s nullglob
    EXISTING_ENVS=("$ENV_DIR"/*.env)
    shopt -u nullglob

    if [[ ${#EXISTING_ENVS[@]} -eq 0 ]]; then
        cp "$ENV_EXAMPLE" "$ENV_DIR/secrets.env"
        chmod 600 "$ENV_DIR/secrets.env"
        echo -e "  ${GREEN}✓${NC} created secrets.env from template"
    fi
fi

ensure_sourced '$HOME/.config/secrets/env.sh' \
    '# Load secrets environment' \
    '[ -f "$HOME/.config/secrets/env.sh" ] && . "$HOME/.config/secrets/env.sh"'

# Reconcile: every name in the template must resolve to a non-empty value.
# This is what stops a new machine from silently running with missing vars.
if [[ -f "$ENV_EXAMPLE" ]]; then
    MISSING=$(
        # shellcheck disable=SC1090
        . "$ENV_TARGET" >/dev/null 2>&1
        sed -n -E 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=.*/\2/p' "$ENV_EXAMPLE" \
            | sort -u \
            | while IFS= read -r var; do
                  [[ -n "${!var:-}" ]] || echo "$var"
              done
    )

    if [[ -n "$MISSING" ]]; then
        echo ""
        echo -e "  ${YELLOW}!${NC} These variables have no value yet — fill them in:"
        echo "$MISSING" | sed 's/^/      /'
        echo -e "    ${YELLOW}→${NC} edit $ENV_DIR/secrets.env, then open a new shell"
    else
        echo -e "  ${GREEN}✓${NC} all variables in secrets.env.example have values"
    fi
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo -e "  ${BLUE}→${NC} open a new shell (or run: source ~/.zshrc) to pick up the changes"
