# dotfiles

Personal dotfiles and scripts. `./install.sh` does the whole install; there is no other dependency.

**This repository is public.** Nothing secret is in it, and nothing secret may be added to it. What gets synced is *names* and *mechanisms* — never values and never hosts:

| Synced through git | Stays on the machine |
|--------------------|----------------------|
| Secret variable *names* (`secrets.env.example`) | Secret values (`~/.config/secrets/*.env`) |
| Machine-agnostic ssh defaults (`ssh/agent.conf`) | Host entries, IPs, usernames (`~/.ssh/config`) |

## What's Inside

| Directory | Contents | Target Location |
|-----------|----------|-----------------|
| `bin/` | Custom shell scripts | `~/.local/bin/` |
| `aliases` | Shared shell aliases | `~/.aliases` |
| `ssh/agent.conf` | Shared ssh defaults (no host entries) | block inside `~/.ssh/config` |
| `secrets.env.example` | Secret variable names (no values) | `~/.config/secrets/secrets.env` |

### Scripts

- **ssh-add-host** - Automate SSH server setup with passwordless login

  ```bash
  ssh-add-host myserver ubuntu 203.0.113.10 22   # add (port defaults to 22)
  ssh-add-host remove myserver                   # remove
  ssh-add-host split                             # migrate an existing config
  ```

  - Each host gets **its own file** at `~/.ssh/config.d/<alias>.conf`, pulled in by `Include config.d/*.conf` in `~/.ssh/config`. Adding, replacing and removing a server is then a file operation instead of line surgery on your whole ssh config.
  - `split` migrates a machine whose hosts are still lumped into `~/.ssh/config`. See [Migrating an existing ssh config](#migrating-an-existing-ssh-config) — it is not a safe refactor by default, and the command is built around that.
  - Optional dependencies: `ssh-copy-id` (recommended) and `sshpass` for non-interactive password entry
  - Set `SSH_ADD_HOST_PASSWORD` (with `sshpass` installed) to provide the initial SSH password; otherwise enter it interactively
  - Generated keys are **passphrase-protected**. This costs no convenience: the tool adds `AddKeysToAgent yes` (plus `UseKeychain yes` on macOS, guarded by `IgnoreUnknown` so Linux/WSL/Git Bash ignore it) to `~/.ssh/config` and loads the key into `ssh-agent`, so the passphrase is typed once, not per connection.
  - Set `SSH_ADD_HOST_NO_PASSPHRASE=1` to generate a key with no passphrase — for CI and other unattended runs only. A passphrase-less key file *is* the credential: anyone who copies it owns the server.

## Installation

```bash
git clone https://github.com/sleepingF0x/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

`install.sh` is idempotent — re-run it any time. It symlinks `bin/` scripts into `~/.local/bin`, symlinks `aliases` to `~/.aliases`, writes the shared ssh block into `~/.ssh/config`, sets up the secrets loader, and adds the source lines to `~/.zshrc` / `~/.bashrc` if they are missing.

Then **open a new shell** — an install script runs in a child process and cannot change the environment of the shell that launched it.

On a fresh machine it will also list any secret variable that still has no value. Fill those in at `~/.config/secrets/secrets.env`.

### Uninstall

```bash
rm ~/.aliases ~/.local/bin/ssh-add-host
```

Then drop the `. "$HOME/.aliases"` and `. "$HOME/.config/secrets/env.sh"` lines from your shell rc, and delete the `# >>> dotfiles ssh-agent >>>` block from `~/.ssh/config`.

## Usage

### Adding a New Script

1. Add your script to `bin/`
2. Make it executable: `chmod +x bin/your-script`
3. Re-run `./install.sh`

### Shared Aliases

The root `aliases` file is symlinked to `~/.aliases` by `./install.sh`.
If `~/.aliases` already exists and is not managed by this repo, the installer first moves it to a timestamped backup.
The installer also appends this source line to `~/.zshrc` and `~/.bashrc` if missing:

```sh
[ -f "$HOME/.aliases" ] && . "$HOME/.aliases"
```

### Shared SSH Defaults

Your ssh config is split in two, along the line this whole repo is organised on:

| Where | What | In git? |
|-------|------|---------|
| `ssh/agent.conf` | The `Host *` defaults, identical on every machine | Yes |
| `~/.ssh/config.d/<alias>.conf` | One file per server — `HostName`, `User`, `Port` | **No** |
| `~/.ssh/config` | The `Include`, plus the agent block written between markers | **No** |

**Host entries never go in the repo.** `HostName`, `User`, `Port` and IPs are reconnaissance data, and this repo is public.

A note on the `Include` glob, because it is easy to get wrong and fails silently. OpenSSH uses `glob(3)`, where `**` is **not** recursive — it is just two `*`, and `*` never crosses a `/`. So `config.d/*.conf` matches flat files, while `config.d/**/*.conf` matches only files exactly *one directory deep*. Point it at the wrong shape and every host vanishes with no error: ssh simply treats the alias as a literal hostname.

### Migrating an existing ssh config

On a machine whose hosts are still lumped into `~/.ssh/config`:

```bash
ssh-add-host split
```

**Splitting is not a safe refactor by default**, which is the whole reason this is a command and not a paragraph telling you to move the blocks by hand.

ssh takes the **first** value it sees for a keyword. So in a config like this, `foo` is currently using `ServerAliveInterval 60` — the `Host *` block above it wins:

```sshconfig
Host *
    ServerAliveInterval 60
Host foo
    ServerAliveInterval 30    ← loses today
```

Move `foo` into `config.d/foo.conf` and the `Include` at the top of the file is read first, so `foo` now gets its own **30**. The value flipped, and **ssh reports no error** — you would find out when a connection behaves differently months later.

So `split` snapshots what `ssh -G` resolves for every host, performs the move, compares all of them again, and if a single value moved it **restores the original config, deletes the files it created, and tells you which host and which keyword changed**. `Host *` pattern blocks are never moved, since their meaning is their position.

`./install.sh` appends the block to the end of `~/.ssh/config`, between markers:

```sshconfig
# >>> dotfiles ssh-agent >>>
Host *
    IgnoreUnknown UseKeychain
    AddKeysToAgent yes
    UseKeychain yes
# <<< dotfiles ssh-agent <<<
```

Edit `ssh/agent.conf` and re-run `./install.sh` to update every machine — the marked region is replaced in place. `bin/ssh-add-host` writes the same block (it owns the implementation; `install.sh` calls `ssh-add-host ensure-agent-config`), so a standalone copy of the script still works without this repo.

Three design points worth knowing, all of them the result of testing rather than taste. The first two follow from the same fact: **ssh_config has no block terminators**, so a directive belongs to the most recent `Host` block above it, whether or not that was intended.

- **It is a literal `Host *` block, not an `Include`.** An `Include` inherits the scope of whatever `Host` block precedes it. The day another tool (VS Code Remote, OrbStack, …) prepends a block to `~/.ssh/config`, an `Include` below it silently applies to that one host and nothing else. A `Host *` block starts its own scope, so it reaches every host from anywhere in the file.
- **It is appended, not prepended.** By the same rule, a block at the *top* of the file swallows every top-level directive below it into its scope. Real configs have those — OrbStack's own `Include` carries the comment *"This only works if it's at the top of ssh_config (before any Host blocks)"*. Since a `Host *` block works from anywhere, going first buys nothing and risks that. Appending also lets a per-host setting override these defaults, which is the right way round.
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

### Adding a New Config

Before moving any file from `$HOME` into this repo, ask what is in it. A public repo will happily publish an API key sitting in a `.zshrc`, or a server list sitting in an `~/.ssh/config` — `.gitignore` cannot save you from a file you deliberately `git add`.

The pattern used here splits every config in two:

- The half that is the same on every machine goes in the repo (`aliases`, `ssh/agent.conf`).
- The half that is a secret or identifies a host stays outside it, and only its *shape* is tracked (`secrets.env.example`).

Follow that split and `install.sh` will reassemble the two on each machine.

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
