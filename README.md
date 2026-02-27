# dotfiles

Personal dotfiles and scripts managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Inside

| Directory | Contents | Target Location |
|-----------|----------|-----------------|
| `bin/` | Custom shell scripts | `~/.local/bin/` |

### Scripts

- **ssh-add-host** - Automate SSH server setup with passwordless login

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

# Install all configurations
stow bin -t ~/.local/bin

# Or use the install script
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
├── bin/                    # Executable scripts
│   └── ssh-add-host
├── install.sh              # Alternative install script
└── README.md
```

## License

MIT
