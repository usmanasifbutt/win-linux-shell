# win-linux-shell

Make Windows PowerShell behave like Linux/macOS — one command, reusable on every machine.

## What's missing on Windows that this adds

- **Unix commands that don't exist or don't work** — `rm -rf`, `cp -r`, `grep`, `sed`, `awk`, `nano`, `which`, `touch`, `open`, `pbcopy`/`pbpaste`. PowerShell's `rm`/`cp` don't take these flags, and `curl` is aliased to `Invoke-WebRequest`, not the real thing.
- **No themed prompt** — plain `PS>` by default; this adds oh-my-posh.
- **No history search / emacs editing** — off by default; this turns them on (`Ctrl+R`, `↑`/`↓` prefix search).

---

## Install

### Option A — one line, works on a fresh machine (recommended)

No git, no bash needed to start — installs Git for Windows, PowerShell 7, and oh-my-posh for you. Run in **Windows PowerShell** (`Win+X` → *Terminal*):

```powershell
irm https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.ps1 | iex
```

Close all terminal windows and reopen when it finishes.

### Option B — clone (if you already have Git Bash)

```bash
git clone https://github.com/usmanasifbutt/win-linux-shell.git && cd win-linux-shell && bash setup.sh
```

### Updating

```bash
git -C ~/.win-linux-shell pull
```

Then run `reload` in PowerShell (or open a new tab).

---

## Options

Not needed for the first run — only when you want to customize or skip a step, then re-run. Two entry points, two flag styles:

- **Installed via Option A?** You have `bootstrap.ps1` at `~\.win-linux-shell\bootstrap.ps1` (it downloaded the whole repo, including `setup.sh` — bash isn't required for Option A itself, but once it installs Git for Windows, `bash setup.sh` works too). Use PowerShell flags:
  ```powershell
  .\bootstrap.ps1 -Theme atomic -SkipTerminal
  ```
- **Installed via Option B?** Use bash flags from inside the clone:
  ```bash
  bash setup.sh --theme atomic --no-terminal
  ```

| bash / `setup.sh` | PowerShell / `bootstrap.ps1` | Effect |
|---|---|---|
| `--theme <name>` | `-Theme <name>` | oh-my-posh theme (default: `slim`) |
| `--gnu-bin <path>` | `-GnuBin <path>` | force the coreutils dir |
| `--no-update` | `-SkipPowerShellUpdate` | skip PowerShell 7 install |
| `--no-git` | `-SkipGit` | skip Git for Windows install |
| `--no-terminal` | `-SkipTerminal` | don't touch Windows Terminal |
| `--no-omp` | `-SkipOhMyPosh` | skip oh-my-posh install |
| `--no-profile` | `-SkipProfile` | don't touch `$PROFILE` |

> oh-my-posh has no theme literally named `minimal` — its builtin minimalist theme is **`slim`** (vendored in this repo, used by default). `-Theme`/`-GnuBin` map to env vars read at shell start: `WIN_LINUX_SHELL_THEME`, `WIN_LINUX_SHELL_GNUBIN`.

---

## What it does

Installs/updates PowerShell 7 → installs Git for Windows if missing → installs oh-my-posh if missing → points Windows Terminal's default profile at PowerShell 7 → wires `profile.ps1` into your `$PROFILE`. Every step is idempotent and safe to re-run. No elevation, no file deletion, only per-user writes.

If the Windows Terminal step can't patch `settings.json` (locked, non-standard install), set it by hand: Windows Terminal → `Ctrl+,` → *Startup* → *Default profile* → **PowerShell**, or set `"defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}"` in `settings.json`.

---

## Requirements

- Windows PowerShell 5.1+ (ships with every supported Windows) to run Option A.
- **winget** (`App Installer`, preinstalled on Windows 11) to auto-install PowerShell 7 / Git / oh-my-posh.

## Uninstall

1. Delete the `# >>> win-linux-shell >>> … <<<` block from `Documents\PowerShell\profile.ps1`.
2. Restore a `settings.json.bak-*` if you want the old Terminal default back.
3. `winget uninstall Git.Git` / `winget uninstall JanDeDobbeleer.OhMyPosh` (optional).
4. Delete `~\.win-linux-shell`.

## License

MIT — see [LICENSE](LICENSE).
