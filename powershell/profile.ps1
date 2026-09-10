# win-linux-shell -- make PowerShell 7 behave like a Linux / macOS shell.
#
# This file is dot-sourced from your $PROFILE by the installer (setup.sh /
# install.ps1). It is machine-independent and safe to source directly:
#
#     . D:\path\to\win-linux-shell\powershell\profile.ps1
#
# Everything here is idempotent -- sourcing it twice does no harm.

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# 1. Real GNU coreutils on PATH (ships with Git for Windows)
#    rm -rf, cp -r, grep, sed, awk, find, head, tail, wc, du, df, less, diff,
#    xargs, nano, ssh ... become the actual coreutils, not cmdlet aliases.
#    Session-only: the persisted user PATH is never modified.
#    Override the location with  $env:WIN_LINUX_SHELL_GNUBIN  before sourcing.
# ---------------------------------------------------------------------------
$__wls_gnu = $env:WIN_LINUX_SHELL_GNUBIN
if (-not $__wls_gnu -or -not (Test-Path -LiteralPath $__wls_gnu)) {
    $__wls_cand = [System.Collections.Generic.List[string]]::new()
    $__git = Get-Command git -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($__git) {
        # ...\Git\cmd\git.exe  ->  ...\Git\usr\bin
        $__wls_cand.Add((Join-Path (Split-Path (Split-Path $__git.Source -Parent) -Parent) 'usr\bin'))
    }
    $__wls_cand.Add('C:\Program Files\Git\usr\bin')
    $__wls_cand.Add('C:\Program Files (x86)\Git\usr\bin')
    if ($env:LOCALAPPDATA) { $__wls_cand.Add((Join-Path $env:LOCALAPPDATA 'Programs\Git\usr\bin')) }
    $__wls_gnu = $__wls_cand | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if ($__wls_gnu -and ($env:PATH -notlike "*$__wls_gnu*")) {
    # Prepended => GNU find/sort win over Windows find.exe/sort.exe (intended).
    # If an MSVC/CMake build ever grabs GNU link.exe, set
    # $env:WIN_LINUX_SHELL_GNUBIN to '' to disable this, or append instead.
    $env:PATH = "$__wls_gnu;$env:PATH"
    $env:PAGER = 'less'
    $env:LESS  = '-FRX'
}

# ---------------------------------------------------------------------------
# 2. Drop cmdlet aliases that mask a real executable of the same name.
#    `wget` is left alone until you actually install one.
#    kill / ps / pwd / echo / man stay native -- Git's cygwin builds of those
#    are worse than PowerShell's on Windows.
# ---------------------------------------------------------------------------
foreach ($__a in 'curl','wget','rm','cp','mv','cat','tee','sort','sleep','diff','tar','ls') {
    if ((Test-Path "Alias:$__a") -and
        (Get-Command $__a -CommandType Application -ErrorAction Ignore)) {
        Remove-Item "Alias:$__a" -Force
    }
}

# ---------------------------------------------------------------------------
# 3. ls family (GNU ls with colour; replaced by eza in section 7 if present)
# ---------------------------------------------------------------------------
if ($__wls_gnu) {
    function ls { ls.exe --color=auto --group-directories-first -hF   @args }
    function ll { ls.exe --color=auto --group-directories-first -hlF  @args }
    function la { ls.exe --color=auto --group-directories-first -halF @args }
    function l  { ll @args }
}

# ---------------------------------------------------------------------------
# 4. Shims for commands with no binary (or where PowerShell should answer)
# ---------------------------------------------------------------------------
function which {
    param([Parameter(ValueFromRemainingArguments)]$Name)
    foreach ($n in $Name) {
        $c = Get-Command $n -ErrorAction Ignore
        if ($c) { if ($c.Source) { $c.Source } else { $c.Definition } }
    }
}
function pbcopy  { $input | Set-Clipboard }
function pbpaste { Get-Clipboard }
function open    { param($Path = '.') Invoke-Item $Path }
function mkcd    { param([Parameter(Mandatory)]$Path) New-Item -ItemType Directory -Force -Path $Path | Out-Null; Set-Location -LiteralPath $Path }
function reload  { . $PROFILE }

if (-not (Get-Command touch -ErrorAction Ignore)) {
    function touch {
        foreach ($p in $args) {
            if (Test-Path -LiteralPath $p) { (Get-Item -LiteralPath $p).LastWriteTime = Get-Date }
            else { New-Item -ItemType File -Path $p -Force | Out-Null }
        }
    }
}
if (-not (Test-Path Function:export) -and -not (Test-Path Alias:export)) {
    function export {
        $kv = ($args -join ' ')
        if ($kv -match '=') { $k, $v = $kv -split '=', 2; Set-Item "Env:$k" $v }
        else { Get-ChildItem Env: }
    }
}

# ---------------------------------------------------------------------------
# 5. PSReadLine -- emacs editing + type-a-prefix history search (zsh/fish feel)
# ---------------------------------------------------------------------------
if (Get-Module PSReadLine -ListAvailable) {
    Set-PSReadLineOption -EditMode Emacs -HistoryNoDuplicates -BellStyle None
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Ctrl+r    -Function ReverseSearchHistory
    try { Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView -ErrorAction Stop } catch {}
}

# ---------------------------------------------------------------------------
# 6. oh-my-posh -- builtin minimal theme ("slim"), vendored in this repo so it
#    works with zero network / zero POSH_THEMES_PATH resolution.
#    Skipped if a prompt was already initialised earlier in your $PROFILE.
#    Change the theme with  $env:WIN_LINUX_SHELL_THEME  (name or full path).
# ---------------------------------------------------------------------------
$__omp = Get-Command oh-my-posh -CommandType Application -ErrorAction Ignore
if ($__omp -and -not $env:POSH_SESSION_ID) {
    $__theme = if ($env:WIN_LINUX_SHELL_THEME) { $env:WIN_LINUX_SHELL_THEME } else { 'slim' }
    $__cfg = $null
    if (Test-Path -LiteralPath $__theme) {
        $__cfg = $__theme                                              # full path given
    } elseif ($env:POSH_THEMES_PATH -and (Test-Path (Join-Path $env:POSH_THEMES_PATH "$__theme.omp.json"))) {
        $__cfg = Join-Path $env:POSH_THEMES_PATH "$__theme.omp.json"   # named builtin
    } elseif (Test-Path (Join-Path $PSScriptRoot 'theme.omp.json')) {
        $__cfg = Join-Path $PSScriptRoot 'theme.omp.json'             # vendored fallback
    }
    if ($__cfg) { oh-my-posh init pwsh --config $__cfg | Invoke-Expression }
    else        { oh-my-posh init pwsh | Invoke-Expression }
}

# ---------------------------------------------------------------------------
# 7. Optional modern replacements -- light up automatically once installed:
#      scoop install eza ripgrep fd bat zoxide fzf
# ---------------------------------------------------------------------------
if (Get-Command eza -ErrorAction Ignore) {
    function ls { eza --group-directories-first --icons=auto @args }
    function ll { eza -lah --git --group-directories-first --icons=auto @args }
    function la { eza -lAh --git --group-directories-first --icons=auto @args }
}
if (Get-Command bat    -ErrorAction Ignore) { function cat { bat --paging=never @args }; $env:BAT_PAGING = 'never' }
if (Get-Command rg     -ErrorAction Ignore) { function grep { rg @args } }
if (Get-Command fd     -ErrorAction Ignore) { function find { fd @args } }
if (Get-Command zoxide -ErrorAction Ignore) { try { Invoke-Expression (& { (zoxide init powershell | Out-String) }) } catch {} }
if (Get-Command fzf    -ErrorAction Ignore) { $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border' }

Remove-Variable __wls_gnu, __wls_cand, __git, __a, __omp, __theme, __cfg -ErrorAction Ignore
