# win-linux-shell

Make a **boring Windows PowerShell** behave like the **Linux / macOS shell** you
already know — in one command, reproducible on every machine you touch.

- **GNU coreutils on `PATH`** — real `rm -rf`, `cp -r`, `mv`, `grep`, `sed`,
  `awk`, `find`, `head`, `tail`, `wc`, `du`, `df`, `less`, `diff`, `xargs`,
  `nano`, `ssh` … (they ship with Git for Windows; this just unmasks them)
- **`curl`** resolves to the real `curl.exe`, not PowerShell's `Invoke-WebRequest` alias
- **oh-my-posh** prompt — colourful and interactive, using the builtin **minimal**
  theme (`slim`)
- **PSReadLine** — emacs keybindings, type-a-prefix history search (`↑`/`↓`),
  `Ctrl+R`, inline autosuggestions
- **Windows Terminal** default profile switched to **PowerShell 7**
- Shims with no Windows equivalent: `which`, `pbcopy` / `pbpaste`, `open`,
  `mkcd`, `touch`, `export FOO=bar`, `reload`
- Optional: auto-upgrades to `eza` / `bat` / `ripgrep` / `fd` / `zoxide` / `fzf`
  the moment they're installed

---

## Convert a boring shell into a productive one

Run one of these in **Git Bash** on Windows, then close every terminal window and
open a new **Windows Terminal** tab.

### Option A — one line, no clone (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh | bash
```

`bootstrap.sh` checks the repo out to `~/.win-linux-shell` and runs `setup.sh`.
Pass options after `-s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh | bash -s -- --theme atomic --no-terminal
```

Prefer to read it first (piping to a shell always deserves a look):

```bash
curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh -o bootstrap.sh
less bootstrap.sh && bash bootstrap.sh
```

Overrides: `WLS_DIR` (install location, default `~/.win-linux-shell`),
`WLS_REF` (branch or tag, default `main`).

### Option B — clone

```bash
git clone https://github.com/usmanasifbutt/win-linux-shell.git && cd win-linux-shell && bash setup.sh
```

### Option C — tarball, no git

```bash
curl -L https://github.com/usmanasifbutt/win-linux-shell/archive/refs/tags/v1.0.1.tar.gz | tar xz
cd win-linux-shell-1.0.1 && bash setup.sh
```

### Updating later

| Installed with | Update command |
|----------------|----------------|
| Option A | `curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh \| bash` |
| Option B | `cd win-linux-shell && git pull && bash setup.sh` |
| any | `git -C ~/.win-linux-shell pull` then `reload` in PowerShell |

---

## What runs

- **`bootstrap.sh`** (Option A only) — checks the repo out to `~/.win-linux-shell`
  (git clone, or tarball if git is absent), then execs `setup.sh`. Nothing else.
- **`setup.sh`** — the single entry point for a local checkout. Finds a
  PowerShell interpreter and hands off to `powershell/install.ps1`.
- **`powershell/install.ps1`** — four idempotent steps:

| # | Step | Notes |
|---|------|-------|
| 1 | `winget install Microsoft.PowerShell` | installs / upgrades PowerShell 7 |
| 2 | Windows Terminal `defaultProfile` → PowerShell 7 | edits only the `defaultProfile` value in `settings.json` (comments and formatting preserved); timestamped backup first |
| 3 | `winget install JanDeDobbeleer.OhMyPosh` | only if `oh-my-posh` is missing |
| 4 | wire `powershell/profile.ps1` into `$PROFILE` | one managed block in `Documents\PowerShell\profile.ps1`; backed up before any edit |

`--theme` / `--gnu-bin` values are validated (`A–Z a–z 0–9 space . _ : \ / -`)
before being written into your `$PROFILE`. The installer never elevates, never
deletes files, and only writes under your user profile.

### Options

```bash
bash setup.sh --theme slim      # oh-my-posh theme name or full path (default: slim)
bash setup.sh --no-update       # skip the PowerShell 7 winget step
bash setup.sh --no-terminal     # don't touch Windows Terminal settings.json
bash setup.sh --no-omp          # skip installing oh-my-posh
bash setup.sh --help
```

> **Theme note:** oh-my-posh has no theme literally named `minimal`. Its builtin
> minimalist theme is **`slim`**, which is what this repo vendors
> (`powershell/theme.omp.json`) and uses by default. Pick any other with
> `--theme <name>` or `$env:WIN_LINUX_SHELL_THEME`.

---

## Manual step: Windows Terminal default profile

If step 2 reports it could not patch `settings.json` (locked, non-standard
install, running under Windows PowerShell 5.1), set it yourself.

**GUI:** Windows Terminal → `Ctrl+,` → *Startup* → *Default profile* → **PowerShell**

**JSON:** open
`C:\Users\<you>\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
and set:

```jsonc
"defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
```

`{574e775e-4f2a-5b96-ac1e-a2962a402336}` is the fixed GUID Windows Terminal
assigns to the PowerShell 7 (`Windows.Terminal.PowershellCore`) profile.

---

## How it stays reusable

- `powershell/profile.ps1` is **machine-independent** — it discovers the GNU
  bin directory from wherever Git is installed, no hard-coded paths.
- The installer adds a single **managed block** to your `$PROFILE`:

  ```powershell
  # >>> win-linux-shell >>>
  $env:WIN_LINUX_SHELL_THEME = 'slim'
  $__wls = 'D:\...\win-linux-shell\powershell\profile.ps1'
  if (Test-Path -LiteralPath $__wls) { . $__wls }
  Remove-Variable __wls -ErrorAction Ignore
  # <<< win-linux-shell <<<
  ```

  Re-running `setup.sh` **refreshes** that block in place; it never duplicates.
  Delete the repo folder and the block becomes a harmless no-op.
- Update everywhere with `git pull` — no re-install needed, just `reload` (or a
  new tab).

### Environment overrides

| Variable | Effect |
|----------|--------|
| `WIN_LINUX_SHELL_THEME` | oh-my-posh theme name or full path |
| `WIN_LINUX_SHELL_GNUBIN` | force the GNU coreutils directory (else auto-detected from Git) |

---

## Requirements

- **Git for Windows** (provides Git Bash to run `setup.sh`, and the GNU coreutils)
- **winget** (`App Installer`, preinstalled on Windows 11) — for steps 1 & 3
- Windows 10 1809+ / Windows 11

## Uninstall

1. Delete the `# >>> win-linux-shell >>> … <<<` block from
   `Documents\PowerShell\profile.ps1`.
2. Restore a `settings.json.bak-*` backup if you want the old Terminal default back.
3. `winget uninstall JanDeDobbeleer.OhMyPosh` (optional).

## License

MIT — see [LICENSE](LICENSE).
