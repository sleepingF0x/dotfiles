#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/fakebin" "$tmpdir/home/.ssh"
printf 'PRIVATE\n' > "$tmpdir/home/.ssh/id_ed25519"
printf 'PUBLIC\n' > "$tmpdir/home/.ssh/id_ed25519.pub"
chmod 600 "$tmpdir/home/.ssh/id_ed25519"

log="$tmpdir/calls.log"
stdout="$tmpdir/stdout.log"
stderr="$tmpdir/stderr.log"

cat > "$tmpdir/fakebin/ssh" <<'FAKE_SSH'
#!/usr/bin/env bash
{
    printf 'ssh'
    for arg in "$@"; do
        printf '\t%s' "$arg"
    done
    printf '\n'
} >> "$SSH_ADD_HOST_TEST_LOG"

if [[ "${1:-}" == "-G" ]]; then
    echo "user root"
    echo "hostname 203.0.113.10"
    echo "port 5022"
    echo "identityfile $HOME/.ssh/id_ed25519"
fi

exit 0
FAKE_SSH

cat > "$tmpdir/fakebin/ssh-copy-id" <<'FAKE_SSH_COPY_ID'
#!/usr/bin/env bash
{
    printf 'ssh-copy-id'
    for arg in "$@"; do
        printf '\t%s' "$arg"
    done
    printf '\n'
} >> "$SSH_ADD_HOST_TEST_LOG"

exit 0
FAKE_SSH_COPY_ID

chmod +x "$tmpdir/fakebin/ssh" "$tmpdir/fakebin/ssh-copy-id"

if ! PATH="$tmpdir/fakebin:$PATH" \
    HOME="$tmpdir/home" \
    SSH_ADD_HOST_TEST_LOG="$log" \
    "$repo_root/bin/ssh-add-host" repro root 203.0.113.10 5022 "$tmpdir/home/.ssh/id_ed25519" \
    >"$stdout" 2>"$stderr"; then
    echo "ssh-add-host failed unexpectedly"
    cat "$stdout"
    cat "$stderr" >&2
    exit 1
fi

if grep -q "password auth ok" "$log"; then
    echo "unexpected password-auth preflight call found"
    cat "$log"
    exit 1
fi

copy_auth_calls=$(grep -Ec $'^(ssh-copy-id\t|ssh\t-o\tConnectTimeout=10\t-o\tBatchMode=no)' "$log" || true)
if [[ "$copy_auth_calls" -ne 1 ]]; then
    echo "expected exactly one password-capable copy command, got $copy_auth_calls"
    cat "$log"
    exit 1
fi

ssh_copy_id_calls=$(grep -Ec $'^ssh-copy-id\t' "$log" || true)
if [[ "$ssh_copy_id_calls" -ne 1 ]]; then
    echo "expected ssh-copy-id to run exactly once, got $ssh_copy_id_calls"
    cat "$log"
    exit 1
fi

if ! grep -q $'^ssh\t-o\tConnectTimeout=10\t-o\tBatchMode=yes' "$log"; then
    echo "expected final passwordless BatchMode=yes test"
    cat "$log"
    exit 1
fi

echo "ok - ssh-add-host copy flow uses one password-capable command"
