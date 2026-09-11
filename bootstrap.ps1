<#
.SYNOPSIS
    win-linux-shell -- zero-dependency bootstrap for a fresh Windows machine.

.DESCRIPTION
    Needs only stock Windows PowerShell (5.1+) -- no git, no Git Bash, no curl
    required to start. Fetches win-linux-shell into a stable folder (git clone
    if git is available, a plain zip download otherwise) and hands off to
    powershell/install.ps1.

    This is the entry point for a machine that has nothing on it yet. Once it
    has run once, `bash setup.sh` / `bash bootstrap.sh` also work, because Git
    for Windows (and therefore Git Bash) is one of the things it installs.

.EXAMPLE
    irm https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.ps1 | iex

.EXAMPLE
    # to pass parameters through a piped run:
    $s = irm https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.ps1
    & ([scriptblock]::Create($s)) -Theme atomic -SkipTerminal

.EXAMPLE
    # or download first, then run (lets you read it before executing):
    iwr https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.ps1 -OutFile bootstrap.ps1
    powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Theme atomic
#>
[CmdletBinding()]
param(
    [string] $Theme = 'slim',
    [string] $GnuBin,
    [string] $WlsDir = (Join-Path $HOME '.win-linux-shell'),
    [string] $Ref = 'main',
    [switch] $SkipPowerShellUpdate,
    [switch] $SkipGit,
    [switch] $SkipTerminal,
    [switch] $SkipOhMyPosh,
    [switch] $SkipProfile
)

$ErrorActionPreference = 'Stop'
$Repo = 'usmanasifbutt/win-linux-shell'

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }

if ([string]::IsNullOrWhiteSpace($WlsDir)) { throw 'Refusing empty -WlsDir.' }
$full = [System.IO.Path]::GetFullPath($WlsDir).TrimEnd('\')
$unsafe = @(
    [System.IO.Path]::GetFullPath($HOME).TrimEnd('\'),
    [System.IO.Path]::GetPathRoot($full).TrimEnd('\')
)
if ($unsafe -contains $full) { throw "Refusing unsafe -WlsDir '$WlsDir' (your home directory or a drive root)." }

Info "win-linux-shell bootstrap -> $full  (ref: $Ref)"

$hasGit = [bool](Get-Command git -CommandType Application -ErrorAction Ignore)
$looksLikeOurs = Test-Path -LiteralPath (Join-Path $full 'setup.sh')

if ($hasGit -and (Test-Path -LiteralPath (Join-Path $full '.git'))) {
    git -C $full fetch --depth 1 origin $Ref
    git -C $full checkout -q -B $Ref FETCH_HEAD
    Info 'updated existing checkout'
} elseif ($hasGit -and -not (Test-Path -LiteralPath $full)) {
    git clone --depth 1 --branch $Ref "https://github.com/$Repo.git" $full
    Info 'cloned'
} else {
    if ((Test-Path -LiteralPath $full) -and (Get-ChildItem -LiteralPath $full -Force -ErrorAction Ignore) -and -not $looksLikeOurs) {
        throw "'$full' already exists and doesn't look like a win-linux-shell checkout. Remove it or pass -WlsDir, then retry."
    }
    if (-not $hasGit) { Info 'git not found -- downloading a zip instead' }
    else { Info "downloading a zip ('$full' exists without .git)" }

    $zip     = Join-Path $env:TEMP ("wls-{0}.zip" -f ([guid]::NewGuid()))
    $extract = Join-Path $env:TEMP ("wls-{0}"     -f ([guid]::NewGuid()))
    try {
        try   { Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repo/archive/refs/heads/$Ref.zip" -OutFile $zip }
        catch { Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repo/archive/refs/tags/$Ref.zip"  -OutFile $zip }
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
        $inner = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
        New-Item -ItemType Directory -Force -Path $full | Out-Null
        Copy-Item -LiteralPath (Join-Path $inner.FullName '*') -Destination $full -Recurse -Force
        Info 'downloaded'
    } finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction Ignore
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction Ignore
    }
}

$installer = Join-Path $full 'powershell\install.ps1'
if (-not (Test-Path -LiteralPath $installer)) { throw "install.ps1 not found under $full -- checkout looks incomplete." }

$installArgs = @{ Theme = $Theme }
if ($GnuBin)               { $installArgs.GnuBin              = $GnuBin }
if ($SkipPowerShellUpdate) { $installArgs.SkipPowerShellUpdate = $true }
if ($SkipGit)               { $installArgs.SkipGit              = $true }
if ($SkipTerminal)         { $installArgs.SkipTerminal          = $true }
if ($SkipOhMyPosh)         { $installArgs.SkipOhMyPosh         = $true }
if ($SkipProfile)          { $installArgs.SkipProfile          = $true }

& $installer @installArgs
