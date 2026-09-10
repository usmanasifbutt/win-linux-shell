#Requires -Version 5.1
<#
.SYNOPSIS
    Installer for win-linux-shell. Normally invoked through ../setup.sh, but can
    be run directly:  pwsh -NoProfile -File powershell/install.ps1

.DESCRIPTION
    1. Updates / installs PowerShell 7 (winget).
    2. Points Windows Terminal's defaultProfile at PowerShell 7.
    3. Installs oh-my-posh (winget) if missing.
    4. Wires powershell/profile.ps1 into $PROFILE.CurrentUserAllHosts.

    Every step is idempotent and re-runnable on any machine.
#>
[CmdletBinding()]
param(
    [string] $Theme = 'slim',
    [string] $TerminalSettings,
    [string] $GnuBin,
    [switch] $SkipPowerShellUpdate,
    [switch] $SkipTerminal,
    [switch] $SkipOhMyPosh
)

$ErrorActionPreference = 'Stop'
$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ProfileSrc = Join-Path $PSScriptRoot 'profile.ps1'
$PwshGuid   = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'   # Windows.Terminal.PowershellCore

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    $m"   -ForegroundColor Green }
function Warn($m) { Write-Host "    $m"   -ForegroundColor Yellow }

function Have($name) { [bool](Get-Command $name -CommandType Application -ErrorAction Ignore) }

# Re-launch under PowerShell 7 if we were started by Windows PowerShell 5.1
# (setup.sh falls back to powershell.exe when pwsh is not yet installed).
if ($PSVersionTable.PSVersion.Major -lt 7) {
    if (-not (Have 'pwsh') -and -not $SkipPowerShellUpdate -and (Have 'winget')) {
        Write-Host '==> Bootstrapping PowerShell 7 ...' -ForegroundColor Cyan
        & winget install --id Microsoft.PowerShell --exact --source winget `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
        $env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('PATH','User')
    }
    $pwshExe = Get-Command pwsh -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($pwshExe) {
        & $pwshExe.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @PSBoundParameters
        exit $LASTEXITCODE
    }
    Write-Warning 'pwsh 7 unavailable; continuing under Windows PowerShell 5.1 (Terminal JSON step may be skipped).'
}

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
Step 'oh-my-posh'
if ($SkipOhMyPosh) {
    Warn 'skipped (-SkipOhMyPosh)'
} elseif (Have 'oh-my-posh') {
    Ok "already installed ($(& oh-my-posh version))"
} else {
    [void](Invoke-Winget @('install','--id','JanDeDobbeleer.OhMyPosh','--exact','--source','winget',
        '--accept-package-agreements','--accept-source-agreements','--disable-interactivity'))
    # refresh PATH for the rest of this run
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('PATH','User')
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

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Warn 'need PowerShell 7 to patch settings.json safely. Set it manually:'
        Warn "  `"defaultProfile`": `"$PwshGuid`","
    } elseif (-not $settings) {
        Warn 'Windows Terminal settings.json not found. Set it manually:'
        Warn '  Windows Terminal -> Settings (Ctrl+,) -> Startup -> Default profile -> PowerShell'
        Warn "  or add this to settings.json:  `"defaultProfile`": `"$PwshGuid`","
    } else {
        try {
            $json = Get-Content -LiteralPath $settings -Raw
            $obj  = $json | ConvertFrom-Json -AsHashtable
            if ($obj.defaultProfile -eq $PwshGuid) {
                Ok "already set ($settings)"
            } else {
                $bak = "$settings.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
                Copy-Item -LiteralPath $settings -Destination $bak -Force
                $obj.defaultProfile = $PwshGuid
                ($obj | ConvertTo-Json -Depth 32) | Set-Content -LiteralPath $settings -Encoding utf8
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
$target = $PROFILE.CurrentUserAllHosts        # ...\Documents\PowerShell\profile.ps1
$dir    = Split-Path $target -Parent
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

$begin = '# >>> win-linux-shell >>>'
$end   = '# <<< win-linux-shell <<<'
$block = @"
$begin
# Managed by win-linux-shell installer -- edit powershell/profile.ps1 in the repo instead.
`$env:WIN_LINUX_SHELL_THEME = '$Theme'
$(if ($GnuBin) { "`$env:WIN_LINUX_SHELL_GNUBIN = '$GnuBin'`n" })`$__wls = '$ProfileSrc'
if (Test-Path -LiteralPath `$__wls) { . `$__wls }
Remove-Variable __wls -ErrorAction Ignore
$end
"@

$existing = if (Test-Path -LiteralPath $target) { Get-Content -LiteralPath $target -Raw } else { '' }
if ($existing.Contains($begin) -and $existing.Contains($end)) {
    $pre  = $existing.Substring(0, $existing.IndexOf($begin)).TrimEnd()
    $post = $existing.Substring($existing.IndexOf($end) + $end.Length)
    Set-Content -LiteralPath $target -Value ($pre + "`r`n" + $block + $post) -Encoding utf8
    Ok "refreshed block in $target"
} else {
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
