# dotfiles

Personal dotfiles and scripts managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Inside

| Directory | Contents | Target Location |
|-----------|----------|-----------------|
| `bin/` | Custom shell scripts | `~/.local/bin/` |
| `aliases` | Shared shell aliases | `~/.aliases` |

### Scripts

- **ssh-add-host** - Automate SSH server setup with passwordless login
  - Optional dependencies: `ssh-copy-id` (recommended) and `sshpass` for non-interactive password entry
  - Set `SSH_ADD_HOST_PASSWORD` (with `sshpass` installed) to provide the initial SSH password; otherwise enter it interactively

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
├── bin/                    # Executable scripts
│   └── ssh-add-host
├── install.sh              # Installer for scripts and aliases
└── README.md
```

## License

MIT
