#Requires -Version 5.1
<#
.SYNOPSIS
    Installer for win-linux-shell. Normally invoked through ../setup.sh, but can
    be run directly:  pwsh -NoProfile -File powershell/install.ps1

.DESCRIPTION
    1. Updates / installs PowerShell 7 (winget).
    2. Installs Git for Windows (winget) if missing -- it's what supplies the
       GNU coreutils profile.ps1 unmasks, so nothing else here works without it.
    3. Installs oh-my-posh (winget) if missing.
    4. Points Windows Terminal's defaultProfile at PowerShell 7.
    5. Wires powershell/profile.ps1 into $PROFILE.CurrentUserAllHosts.

    Every step is idempotent and re-runnable on any machine. Needs only stock
    Windows PowerShell 5.1 to start -- see ../bootstrap.ps1 for a route in that
    doesn't require git or bash to already be installed.
#>
[CmdletBinding()]
param(
    [string] $Theme = 'slim',
    [string] $TerminalSettings,
    [string] $GnuBin,
    [switch] $SkipPowerShellUpdate,
    [switch] $SkipGit,
    [switch] $SkipTerminal,
    [switch] $SkipOhMyPosh,
    [switch] $SkipProfile
)

$ErrorActionPreference = 'Stop'
$ProfileSrc = Join-Path $PSScriptRoot 'profile.ps1'
$PwshGuid   = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'   # Windows.Terminal.PowershellCore

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    $m"   -ForegroundColor Green }
function Warn($m) { Write-Host "    $m"   -ForegroundColor Yellow }

function Have($name) { [bool](Get-Command $name -CommandType Application -ErrorAction Ignore) }
function Refresh-Path {
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('PATH','User')
}

# Re-launch under PowerShell 7 if we were started by Windows PowerShell 5.1
# (setup.sh falls back to powershell.exe when pwsh is not yet installed).
if ($PSVersionTable.PSVersion.Major -lt 7) {
    if (-not (Have 'pwsh') -and -not $SkipPowerShellUpdate -and (Have 'winget')) {
        Write-Host '==> Bootstrapping PowerShell 7 ...' -ForegroundColor Cyan
        & winget install --id Microsoft.PowerShell --exact --source winget `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
        Refresh-Path
    }
    $pwshExe = Get-Command pwsh -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($pwshExe) {
        & $pwshExe.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @PSBoundParameters
        exit $LASTEXITCODE
    }
    Write-Warning 'pwsh 7 unavailable; continuing under Windows PowerShell 5.1.'
}

# Values that get written verbatim into $PROFILE must not be able to break out of
# the single-quoted strings we emit, or inject code that runs on every shell start.
function Assert-Safe($name, $value) {
    if ($value -and $value -notmatch '^[A-Za-z0-9 ._:\\/-]+$') {
        throw "Unsafe -$name value '$value'. Allowed: letters, digits, space, and . _ : \ / -"
    }
}
Assert-Safe 'Theme'  $Theme
Assert-Safe 'GnuBin' $GnuBin

function Invoke-Winget([string[]] $Args) {
    if (-not (Have 'winget')) {
        Warn "winget not found -- install 'App Installer' from the Microsoft Store, then re-run."
        return $false
    }
    Write-Host "    winget $($Args -join ' ')" -ForegroundColor DarkGray
    & winget @Args
    # 0 = ok ; -1978335189 (0x8A15002B) = 'no applicable upgrade' ; treat as ok
    if ($LASTEXITCODE -in 0, -1978335189, -1978335212) { return $true }
    Warn "winget exited with $LASTEXITCODE (continuing)"
    return $false
}

# ---------------------------------------------------------------------------
Step 'PowerShell 7'
if ($SkipPowerShellUpdate) {
    Warn 'skipped (-SkipPowerShellUpdate)'
} else {
    [void](Invoke-Winget @('install','--id','Microsoft.PowerShell','--exact','--source','winget',
        '--accept-package-agreements','--accept-source-agreements','--disable-interactivity'))
    $pwsh = Get-Command pwsh -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($pwsh) { Ok "pwsh -> $($pwsh.Source)" } else { Warn 'pwsh still not on PATH -- open a new terminal after install completes.' }
}

# ---------------------------------------------------------------------------
Step 'Git for Windows'
# This is the actual source of the GNU coreutils profile.ps1 unmasks (rm, cp,
# grep, sed, nano, ...) -- without it the "Linux commands" half of this repo
# is a no-op, so it gets installed unless explicitly skipped.
if ($SkipGit) {
    Warn 'skipped (-SkipGit)'
} elseif (Have 'git') {
    Ok "already installed ($(& git --version))"
} else {
    [void](Invoke-Winget @('install','--id','Git.Git','--exact','--source','winget',
        '--accept-package-agreements','--accept-source-agreements','--disable-interactivity'))
    Refresh-Path
    if (Have 'git') { Ok "installed ($(& git --version))" }
    else { Warn 'installed, but not visible yet -- it will work in a new terminal.' }
}

# ---------------------------------------------------------------------------
Step 'oh-my-posh'
if ($SkipOhMyPosh) {
    Warn 'skipped (-SkipOhMyPosh)'
} elseif (Have 'oh-my-posh') {
    Ok "already installed ($(& oh-my-posh version))"
} else {
    [void](Invoke-Winget @('install','--id','JanDeDobbeleer.OhMyPosh','--exact','--source','winget',
        '--accept-package-agreements','--accept-source-agreements','--disable-interactivity'))
    Refresh-Path
    if (Have 'oh-my-posh') { Ok "installed ($(& oh-my-posh version))" }
    else { Warn 'installed, but not visible yet -- it will work in a new terminal.' }
}

# ---------------------------------------------------------------------------
Step "Windows Terminal default profile -> PowerShell 7  $PwshGuid"
if ($SkipTerminal) {
    Warn 'skipped (-SkipTerminal)'
} else {
    $candidates = @()
    if ($TerminalSettings) { $candidates += $TerminalSettings }
    $candidates += @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $settings = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

    if (-not $settings) {
        Warn 'Windows Terminal settings.json not found. Set it manually:'
        Warn '  Windows Terminal -> Settings (Ctrl+,) -> Startup -> Default profile -> PowerShell'
        Warn "  or add this to settings.json:  `"defaultProfile`": `"$PwshGuid`","
    } else {
        try {
            # Targeted string edit -- preserves // comments, key order and formatting
            # that a ConvertFrom-Json / ConvertTo-Json round-trip would silently drop.
            $text = Get-Content -LiteralPath $settings -Raw
            $rx   = [regex]'("defaultProfile"\s*:\s*)"(.*?)"'
            $m    = $rx.Match($text)
            if ($m.Success -and $m.Groups[2].Value -eq $PwshGuid) {
                Ok "already set ($settings)"
            } else {
                $bak = "$settings.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
                Copy-Item -LiteralPath $settings -Destination $bak -Force
                if ($m.Success) {
                    $new = $rx.Replace($text, "`${1}`"$PwshGuid`"", 1)
                } else {
                    # no key present -- insert right after the first opening brace
                    $i = $text.IndexOf('{')
                    if ($i -lt 0) { throw 'not a JSON object' }
                    $new = $text.Substring(0, $i + 1) + "`r`n    `"defaultProfile`": `"$PwshGuid`"," + $text.Substring($i + 1)
                }
                [System.IO.File]::WriteAllText($settings, $new, (New-Object System.Text.UTF8Encoding $false))
                Ok "updated ($settings)"
                Ok "backup  $bak"
            }
        } catch {
            Warn "could not patch $settings automatically: $($_.Exception.Message)"
            Warn "add manually:  `"defaultProfile`": `"$PwshGuid`","
        }
    }
}

# ---------------------------------------------------------------------------
Step "Wire profile.ps1 into `$PROFILE"
if ($SkipProfile) {
    Warn 'skipped (-SkipProfile)'
    return
}
$target = $PROFILE.CurrentUserAllHosts        # ...\Documents\PowerShell\profile.ps1
$dir    = Split-Path $target -Parent
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

$begin = '# >>> win-linux-shell >>>'
$end   = '# <<< win-linux-shell <<<'
# Escape single quotes so nothing can break out of the strings below (values are
# also validated by Assert-Safe above -- this is belt and braces).
$q = { param($s) $s -replace "'", "''" }
$themeLit = & $q $Theme
$gnuLine  = if ($GnuBin) { "`$env:WIN_LINUX_SHELL_GNUBIN = '$(& $q $GnuBin)'`r`n" } else { '' }
$srcLit   = & $q $ProfileSrc
$block = @"
$begin
# Managed by win-linux-shell installer -- edit powershell/profile.ps1 in the repo instead.
`$env:WIN_LINUX_SHELL_THEME = '$themeLit'
$gnuLine`$__wls = '$srcLit'
if (Test-Path -LiteralPath `$__wls) { . `$__wls }
Remove-Variable __wls -ErrorAction Ignore
$end
"@

$existing = if (Test-Path -LiteralPath $target) { Get-Content -LiteralPath $target -Raw } else { '' }
$bi = $existing.IndexOf($begin)
$ei = $existing.IndexOf($end)
if ($bi -ge 0 -and $ei -gt $bi) {
    if ($existing.Trim()) {
        Copy-Item -LiteralPath $target -Destination "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
    }
    $pre  = $existing.Substring(0, $bi).TrimEnd()
    $post = $existing.Substring($ei + $end.Length)
    Set-Content -LiteralPath $target -Value ($pre + "`r`n" + $block + $post) -Encoding utf8
    Ok "refreshed block in $target"
} elseif ($bi -ge 0 -or $ei -ge 0) {
    Warn "found a malformed win-linux-shell block in $target -- leaving it alone and appending a fresh one."
    Warn 'Remove the old markers by hand when convenient.'
    Add-Content -LiteralPath $target -Value ("`r`n" + $block) -Encoding utf8
} else {
    if ($existing.Trim()) {
        Copy-Item -LiteralPath $target -Destination "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
    }
    Add-Content -LiteralPath $target -Value ("`r`n" + $block) -Encoding utf8
    Ok "added block to $target"
}

# ---------------------------------------------------------------------------
Write-Host "`n==> Done." -ForegroundColor Cyan
Write-Host @"
    Close every terminal window and open a new Windows Terminal tab.
    You should get the oh-my-posh '$Theme' prompt and working rm -rf / cp -r /
    grep / sed / nano / curl ...  Run  reload  to re-apply without restarting.
"@ -ForegroundColor Green
