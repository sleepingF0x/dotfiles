# dotfiles

Personal dotfiles and scripts managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Inside

| Directory | Contents | Target Location |
|-----------|----------|-----------------|
| `bin/` | Custom shell scripts | `~/.local/bin/` |
| `aliases` | Shared shell aliases | `~/.aliases` |
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
├── bin/                    # Executable scripts
│   └── ssh-add-host
├── install.sh              # Installer for scripts, aliases, and secrets env
└── README.md
```

## License

MIT
