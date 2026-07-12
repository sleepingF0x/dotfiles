# dotfiles

Personal dotfiles and scripts managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Inside

| Directory | Contents | Target Location |
|-----------|----------|-----------------|
| `bin/` | Custom shell scripts | `~/.local/bin/` |
| `aliases` | Shared shell aliases | `~/.aliases` |
| `ssh/agent.conf` | Shared ssh defaults (no host entries) | block inside `~/.ssh/config` |
| `secrets.env.example` | Secret variable names (no values) | `~/.config/secrets/secrets.env` |

### Scripts

- **ssh-add-host** - Automate SSH server setup with passwordless login
  - Optional dependencies: `ssh-copy-id` (recommended) and `sshpass` for non-interactive password entry
  - Set `SSH_ADD_HOST_PASSWORD` (with `sshpass` installed) to provide the initial SSH password; otherwise enter it interactively
  - Generated keys are **passphrase-protected**. This costs no convenience: the tool adds `AddKeysToAgent yes` (plus `UseKeychain yes` on macOS, guarded by `IgnoreUnknown` so Linux/WSL/Git Bash ignore it) to `~/.ssh/config` and loads the key into `ssh-agent`, so the passphrase is typed once, not per connection.
  - Set `SSH_ADD_HOST_NO_PASSPHRASE=1` to generate a key with no passphrase — for CI and other unattended runs only. A passphrase-less key file *is* the credential: anyone who copies it owns the server.

## Installation

### Prerequisites

```bash
# macOS
brew install stow

# Ubuntu/Debian
sudo apt install stow

# Fedora
sudo dnf install stow
```

### Setup

```bash
# Clone this repository
git clone https://github.com/yourusername/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles

# Install scripts via stow
stow bin -t ~/.local/bin

# Or use the install script to install scripts + shared aliases
./install.sh
```

### Uninstall

```bash
# Remove symlinks (preserves the repo)
stow -D bin -t ~/.local/bin
```

## Usage

### Adding a New Script

1. Add your script to `bin/`
2. Make it executable: `chmod +x bin/your-script`
3. Re-run stow: `stow -R bin -t ~/.local/bin`

### Shared Aliases

The root `aliases` file is symlinked to `~/.aliases` by `./install.sh`.
If `~/.aliases` already exists and is not managed by this repo, the installer first moves it to a timestamped backup.
The installer also appends this source line to `~/.zshrc` and `~/.bashrc` if missing:

```sh
[ -f "$HOME/.aliases" ] && . "$HOME/.aliases"
```

### Shared SSH Defaults

`ssh/agent.conf` holds the machine-agnostic half of an ssh config — currently just the `Host *` block that makes a passphrase-protected key affordable. **Host entries never go here.** `HostName`, `User`, `Port` and IPs are reconnaissance data, and this repo is public; they stay in `~/.ssh/config`, which is not tracked.

`./install.sh` writes the block into `~/.ssh/config` between markers:

```sshconfig
# >>> dotfiles ssh-agent >>>
Host *
    IgnoreUnknown UseKeychain
    AddKeysToAgent yes
    UseKeychain yes
# <<< dotfiles ssh-agent <<<
```

Edit `ssh/agent.conf` and re-run `./install.sh` to update every machine — the marked region is replaced in place. `bin/ssh-add-host` writes the same block (it owns the implementation; `install.sh` calls `ssh-add-host ensure-agent-config`), so a standalone copy of the script still works without this repo.

Two design points worth knowing, both of them the result of testing rather than taste:

- **It is a literal `Host *` block, not an `Include`.** ssh_config has no block terminators, so an `Include` inherits the scope of whatever `Host` block precedes it. The day another tool (VS Code Remote, OrbStack, …) prepends a block to `~/.ssh/config`, an `Include` below it silently applies to that one host and nothing else. A `Host *` block starts its own scope and reaches every host from anywhere in the file.
- **An unmarked `AddKeysToAgent` is left alone.** If you wrote a block by hand, the installer declines and says so rather than guessing where your block ends — that guess is how a tool eats half of someone's ssh config.

After editing, the config is verified with `ssh -G`; if ssh rejects it, the previous version is restored.

### Secrets Environment

Secret **values** never enter this repo. Only their **names** do, via `secrets.env.example`, so a new machine knows what it still has to fill in.

| Location | Contents | Tracked? |
|----------|----------|----------|
| `secrets.env.example` | Variable names, empty values | Yes |
| `~/.config/secrets/*.env` | Real values, `chmod 600` | No |
| `~/.config/secrets/env.sh` | Loader — sources every `*.env` above | No (generated) |

`./install.sh` wires this up: it writes the loader, adds the source line to `~/.zshrc` / `~/.bashrc`, and on a fresh machine seeds `~/.config/secrets/secrets.env` from the template. It then checks every name in the template against what actually loaded, and lists any that are still empty:

```
! These variables have no value yet — fill them in:
    JINA_API_KEY
    TWITTER_TOKEN
  → edit ~/.config/secrets/secrets.env, then open a new shell
```

**Adding a variable:** append its name to `secrets.env.example` with an empty value and commit. Every other machine's next `./install.sh` run flags it as missing.

**Splitting by project:** the loader sources *every* `*.env` in the directory, so you can keep `jina.env`, `twitter.env`, etc. side by side instead of one `secrets.env`.

An older hand-written `env.sh` holding secrets inline is detected on upgrade: the installer backs it up and migrates its variables into `secrets.env` before replacing it with the loader.

### Adding New Config Categories

```bash
# Example: Add zsh configs
mkdir zsh
mv ~/.zshrc zsh/
stow zsh -t ~
```

## Directory Structure

```
dotfiles/
├── aliases                 # Shared shell aliases
├── secrets.env.example     # Secret variable NAMES (no values)
├── ssh/
│   └── agent.conf          # Shared ssh defaults (no host entries)
├── bin/                    # Executable scripts
│   └── ssh-add-host
├── install.sh              # Installer for scripts, aliases, ssh defaults, secrets env
└── README.md
```

## License

MIT
