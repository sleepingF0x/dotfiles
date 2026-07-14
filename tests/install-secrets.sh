#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

write_legacy_loader() {
    local target="$1"
    cat > "$target" <<'EOF'
# Split secret loader.
# This loader sources readable sibling *.env files in sorted order.
. "$HOME/.config/secrets/secrets.env"
EOF
}

run_installer() {
    local home="$1"
    HOME="$home" bash "$ROOT/install.sh" >/dev/null
}

# Upgrade from the generated legacy loader: preserve it as a backup, but seed
# secrets.env from the data template instead of copying executable loader code.
UPGRADE_HOME="$TEST_ROOT/upgrade"
mkdir -p "$UPGRADE_HOME/.config/secrets"
touch "$UPGRADE_HOME/.zshrc" "$UPGRADE_HOME/.bashrc"
write_legacy_loader "$UPGRADE_HOME/.config/secrets/env.sh"

run_installer "$UPGRADE_HOME"

cmp -s "$ROOT/secrets.env.example" "$UPGRADE_HOME/.config/secrets/secrets.env"
compgen -G "$UPGRADE_HOME/.config/secrets/env.sh.backup-*" >/dev/null
HOME="$UPGRADE_HOME" zsh -dfc 'source "$HOME/.config/secrets/env.sh"'

# Repair the state produced by the broken migration: quarantine the recursive
# file without disturbing valid sibling env files.
REPAIR_HOME="$TEST_ROOT/repair"
mkdir -p "$REPAIR_HOME/.config/secrets"
touch "$REPAIR_HOME/.zshrc" "$REPAIR_HOME/.bashrc"
printf '%s\n' '# dotfiles-secrets-loader v1' > "$REPAIR_HOME/.config/secrets/env.sh"
printf '%s\n' 'CAP_TEST_VALUE=present' > "$REPAIR_HOME/.config/secrets/cap.env"
write_legacy_loader "$REPAIR_HOME/.config/secrets/secrets.env"

run_installer "$REPAIR_HOME"

[[ ! -e "$REPAIR_HOME/.config/secrets/secrets.env" ]]
compgen -G "$REPAIR_HOME/.config/secrets/secrets.env.legacy-loader-backup-*" >/dev/null
HOME="$REPAIR_HOME" zsh -dfc 'source "$HOME/.config/secrets/env.sh"; [[ "$CAP_TEST_VALUE" = present ]]'

echo "install secrets regression tests passed"
