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
    cat > "$ENV_TARGET" <<'EOF_ENV_SH'
# Split secret loader.
#
# Keep this file as the single entrypoint sourced by your shell startup.
# Put concrete environment variables in sibling .env files:
#
#   ~/.config/secrets/cli-proxy.env
#   ~/.config/secrets/openai.env
#   ~/.config/secrets/my-project.env
#
# This loader sources readable sibling *.env files in sorted order. Files must
# use shell-compatible .env syntax, such as KEY=value or KEY="value with spaces".
# If a later file sets the same variable to a different value, it prints a
# warning without revealing either value; the later file still wins.

if [ -n "${ZSH_VERSION:-}" ]; then
  _secrets_entry="${(%):-%N}"
elif [ -n "${BASH_VERSION:-}" ]; then
  _secrets_entry="${BASH_SOURCE[0]}"
else
  _secrets_entry="${HOME}/.config/secrets/env.sh"
fi

case "$_secrets_entry" in
  /*) ;;
  *) _secrets_entry="${PWD}/${_secrets_entry}" ;;
esac

_secrets_dir="$(cd -P "$(dirname "$_secrets_entry")" >/dev/null 2>&1 && pwd)"
[ -n "$_secrets_dir" ] || _secrets_dir="${HOME}/.config/secrets"

case "$-" in
  *a*) _secrets_entry_allexport_was_set=1 ;;
  *) _secrets_entry_allexport_was_set=0 ;;
esac

if [ -d "$_secrets_dir" ]; then
  while IFS= read -r _secrets_file; do
    _secrets_name="${_secrets_file##*/}"

    case "$_secrets_name" in
      *.backup-*|.*)
        continue
        ;;
    esac

    if [ -r "$_secrets_file" ]; then
      case "$-" in
        *a*) _secrets_allexport_was_set=1 ;;
        *) _secrets_allexport_was_set=0 && set -a ;;
      esac

      . "$_secrets_file"

      set +a

      while IFS= read -r _secrets_var; do
        [ -n "$_secrets_var" ] || continue
        _secrets_tracking_vars="${_secrets_tracking_vars:-} _secrets_seen_${_secrets_var} _secrets_value_${_secrets_var} _secrets_file_${_secrets_var}"

        eval "_secrets_var_is_set=\${$_secrets_var+x}"
        [ "$_secrets_var_is_set" = x ] || continue

        eval "_secrets_current_value=\${$_secrets_var-}"
        eval "_secrets_var_seen=\${_secrets_seen_${_secrets_var}:-}"

        if [ "$_secrets_var_seen" = 1 ]; then
          eval "_secrets_previous_value=\${_secrets_value_${_secrets_var}-}"

          if [ "$_secrets_previous_value" != "$_secrets_current_value" ]; then
            eval "_secrets_previous_file=\${_secrets_file_${_secrets_var}:-unknown}"
            printf 'secrets env warning: %s sets %s differently than %s; later file wins.\n' "$_secrets_name" "$_secrets_var" "$_secrets_previous_file" >&2
          fi
        fi

        eval "_secrets_seen_${_secrets_var}=1"
        eval "_secrets_value_${_secrets_var}=\${_secrets_current_value}"
        eval "_secrets_file_${_secrets_var}=\${_secrets_name}"
      done <<EOF_VARS
$(sed -n -E 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=.*/\2/p' "$_secrets_file" 2>/dev/null | sort -u)
EOF_VARS

      if [ "$_secrets_allexport_was_set" -eq 1 ]; then
        set -a
      else
        set +a
      fi
    fi
  done <<EOF
$(find "$_secrets_dir" -maxdepth 1 -type f -name "*.env" -print 2>/dev/null | sort)
EOF
fi

set +a
eval "unset ${_secrets_tracking_vars:-}"
if [ "$_secrets_entry_allexport_was_set" -eq 1 ]; then
  unset _secrets_allexport_was_set _secrets_current_value _secrets_dir _secrets_entry _secrets_entry_allexport_was_set _secrets_file _secrets_name _secrets_previous_file _secrets_previous_value _secrets_tracking_vars _secrets_var _secrets_var_is_set _secrets_var_seen
  set -a
else
  unset _secrets_allexport_was_set _secrets_current_value _secrets_dir _secrets_entry _secrets_entry_allexport_was_set _secrets_file _secrets_name _secrets_previous_file _secrets_previous_value _secrets_tracking_vars _secrets_var _secrets_var_is_set _secrets_var_seen
  set +a
fi
EOF_ENV_SH
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
