# win-linux-shell

Make a **boring Windows PowerShell** behave like the **Linux / macOS shell** you
already know — in one command, reproducible on every machine you touch.

- **GNU coreutils on `PATH`** — real `rm -rf`, `cp -r`, `mv`, `grep`, `sed`,
  `awk`, `find`, `head`, `tail`, `wc`, `du`, `df`, `less`, `diff`, `xargs`,
  `nano`, `ssh` … (they ship with Git for Windows, which gets installed for
  you if it's missing; this just unmasks the tools already on your machine)
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

### Option A — fresh machine, nothing installed yet (recommended)

A stock Windows box has **PowerShell but no `bash`, no `git`, and `curl` is a
PowerShell alias for `Invoke-WebRequest`** (not the real thing) — so a
`curl | bash` one-liner does not work out of the box. Use PowerShell's own
downloader instead, in **Windows PowerShell or PowerShell 7** (`Win+X` → *Terminal*):

```powershell
irm https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.ps1 | iex
```

`irm` (`Invoke-RestMethod`) and `iex` (`Invoke-Expression`) are built into every
Windows PowerShell since 3.0 — nothing to install first, and no execution-policy
prompt, because the script is evaluated in-memory rather than run as a file.
`bootstrap.ps1` fetches the repo to `~\.win-linux-shell` (via `git` if present,
otherwise a plain zip download — no git needed even for this step) and hands
off to `powershell/install.ps1`, which **installs Git for Windows** among other
things. After it, `bash` and Option B below work too.

To pass options through a piped run:

```powershell
$s = irm https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.ps1
& ([scriptblock]::Create($s)) -Theme atomic -SkipTerminal
```

Or download first and read it before running (recommended — piping to a shell,
`bash` or PowerShell, always deserves a look first):

```powershell
iwr https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.ps1 -OutFile bootstrap.ps1
notepad bootstrap.ps1
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Theme atomic
```

Overrides: `-WlsDir` (install location, default `~\.win-linux-shell`), `-Ref`
(branch or tag, default `main`), `-Theme`, `-GnuBin`, and the same `-Skip*`
switches as `install.ps1` (see [Options](#options)).

### Option B — already have Git Bash

```bash
curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh | bash
```

Same idea as Option A, bash-flavoured: `bootstrap.sh` checks the repo out to
`~/.win-linux-shell` and runs `setup.sh`. Pass options after `-s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh | bash -s -- --theme atomic --no-terminal
```

Overrides: `WLS_DIR`, `WLS_REF`. Close every terminal window and open a new
**Windows Terminal** tab once either option finishes.

### Option C — clone

```bash
git clone https://github.com/usmanasifbutt/win-linux-shell.git && cd win-linux-shell && bash setup.sh
```

### Option D — tarball, no git

```bash
curl -L https://github.com/usmanasifbutt/win-linux-shell/archive/refs/tags/v1.0.2.tar.gz | tar xz
cd win-linux-shell-1.0.2 && bash setup.sh
```

### Updating later

| Installed with | Update command |
|----------------|----------------|
| Option A | `irm https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.ps1 \| iex` |
| Option B | `curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh \| bash` |
| Option C | `cd win-linux-shell && git pull && bash setup.sh` |
| any | `git -C ~/.win-linux-shell pull` then `reload` in PowerShell |

---

## What runs

- **`bootstrap.ps1`** (Option A) — pure PowerShell, no prerequisites. Fetches
  the repo to `~\.win-linux-shell` (git clone, or a zip download if git isn't
  installed yet) and calls `powershell\install.ps1`.
- **`bootstrap.sh`** (Option B) — the same idea for Git Bash: checks the repo
  out to `~/.win-linux-shell`, then execs `setup.sh`.
- **`setup.sh`** — the entry point for a local checkout (Options B–D). Finds a
  PowerShell interpreter and hands off to `powershell/install.ps1`.
- **`powershell/install.ps1`** — five idempotent steps, all reachable from any
  of the options above:

| # | Step | Notes |
|---|------|-------|
| 1 | `winget install Microsoft.PowerShell` | installs / upgrades PowerShell 7 |
| 2 | `winget install Git.Git` | only if `git` is missing — it's what supplies the GNU coreutils; skip and nothing in the "Linux commands" pillar works |
| 3 | `winget install JanDeDobbeleer.OhMyPosh` | only if `oh-my-posh` is missing |
| 4 | Windows Terminal `defaultProfile` → PowerShell 7 | edits only the `defaultProfile` value in `settings.json` (comments and formatting preserved); timestamped backup first |
| 5 | wire `powershell/profile.ps1` into `$PROFILE` | one managed block in `Documents\PowerShell\profile.ps1`; backed up before any edit |

`-Theme` / `-GnuBin` values are validated (`A–Z a–z 0–9 space . _ : \ / -`)
before being written into your `$PROFILE`. The installer never elevates, never
deletes files, and only writes under your user profile.

### Options

Same flags everywhere; `bootstrap.ps1` and `install.ps1` use PowerShell's
`-PascalCase` spelling, `bootstrap.sh` / `setup.sh` use `--kebab-case`.

```bash
bash setup.sh --theme slim      # oh-my-posh theme name or full path (default: slim)
bash setup.sh --gnu-bin <path>  # force the GNU coreutils dir (else auto-detected from Git)
bash setup.sh --no-update       # skip the PowerShell 7 winget step
bash setup.sh --no-git          # skip installing Git for Windows
bash setup.sh --no-terminal     # don't touch Windows Terminal settings.json
bash setup.sh --no-omp          # skip installing oh-my-posh
bash setup.sh --no-profile      # don't touch your PowerShell $PROFILE
bash setup.sh --help
```

> **Theme note:** oh-my-posh has no theme literally named `minimal`. Its builtin
> minimalist theme is **`slim`**, which is what this repo vendors
> (`powershell/theme.omp.json`) and uses by default. Pick any other with
> `--theme <name>` or `$env:WIN_LINUX_SHELL_THEME`.

---

## Manual step: Windows Terminal default profile

If step 4 reports it could not patch `settings.json` (locked or a non-standard
install location), set it yourself.

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

- **Windows PowerShell 5.1** (ships with every supported Windows) to run
  Option A — everything else, including Git for Windows itself, is installed
  for you from there.
- **winget** (`App Installer`) to actually install things — preinstalled on
  Windows 11 and current Windows 10. Without it, `bootstrap.ps1` still fetches
  the repo and wires up your `$PROFILE`, but PowerShell 7 / Git / oh-my-posh
  won't auto-install; get `App Installer` from the Microsoft Store first.
- Windows 10 1809+ / Windows 11

## Uninstall

1. Delete the `# >>> win-linux-shell >>> … <<<` block from
   `Documents\PowerShell\profile.ps1`.
2. Restore a `settings.json.bak-*` backup if you want the old Terminal default back.
3. `winget uninstall JanDeDobbeleer.OhMyPosh` / `winget uninstall Git.Git` (optional
   — the latter also removes Git Bash and the coreutils this repo unmasks).
4. Delete `~\.win-linux-shell` (or wherever you cloned it).

## License

MIT — see [LICENSE](LICENSE).
