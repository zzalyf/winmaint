# ============================================================
#  CW Maintenance Utility (WinMaint) - GUI, WinUtil-style
#  Single self-contained script. WPF dark UI (Catppuccin Mocha).
#  Local:  powershell -NoProfile -ExecutionPolicy Bypass -File .\WinMaint.ps1
#  Hosted: irm <WinMaintUrl> | iex
# ============================================================
param(
    [switch]$SelfTest   # build the UI but do not ShowDialog (for headless verification)
)

# Raw URL where this script is published, so it can re-elevate itself when run
# via `irm <url> | iex` (no local file path is available in that mode).
# Replace <user>/<repo> with your GitHub once published.
$WinMaintUrl = 'https://raw.githubusercontent.com/zzalyf/winmaint/main/WinMaint.ps1'
$WMVersion   = '2026.07.01-r9'   # bumped on each release; shown at each run for sanity

# --- Admin guard / self-relaunch ----------------------------
function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not $SelfTest -and -not (Test-Admin)) {
    if ($PSCommandPath) {
        # Local file: relaunch this file elevated.
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
        )
    } elseif ($WinMaintUrl -and $WinMaintUrl -notmatch '<user>') {
        # Hosted (irm | iex): re-elevate by re-fetching and running the script.
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "irm $WinMaintUrl | iex"
        )
    } else {
        Write-Warning "CW Maintenance Utility requires Administrator privileges. Run PowerShell as administrator and try again."
        return
    }
    exit
}

# --- Catppuccin Mocha for the PowerShell console ------------
# Remaps the 16 console colour slots to Catppuccin Mocha RGB via
# SetConsoleScreenBufferInfoEx, so Write-Host's named colours render in-theme.
function Set-CatppuccinConsole {
    try {
        if (-not ('Win32Maint.ConsolePalette' -as [type])) {
            Add-Type -Namespace Win32Maint -Name ConsolePalette -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct COORD { public short X; public short Y; }
[StructLayout(LayoutKind.Sequential)] public struct SMALL_RECT { public short Left; public short Top; public short Right; public short Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct CONSOLE_SCREEN_BUFFER_INFO_EX {
    public uint cbSize; public COORD dwSize; public COORD dwCursorPosition; public ushort wAttributes;
    public SMALL_RECT srWindow; public COORD dwMaximumWindowSize; public ushort wPopupAttributes;
    public bool bFullscreenSupported;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)] public uint[] ColorTable;
}
[DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool GetConsoleScreenBufferInfoEx(IntPtr h, ref CONSOLE_SCREEN_BUFFER_INFO_EX i);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetConsoleScreenBufferInfoEx(IntPtr h, ref CONSOLE_SCREEN_BUFFER_INFO_EX i);
'@
        }
        $h = [Win32Maint.ConsolePalette]::GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        $info = New-Object Win32Maint.ConsolePalette+CONSOLE_SCREEN_BUFFER_INFO_EX
        $info.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($info)
        if (-not [Win32Maint.ConsolePalette]::GetConsoleScreenBufferInfoEx($h, [ref]$info)) { return }
        # COLORREF = 0x00BBGGRR. Catppuccin Mocha, mapped onto the 16 ConsoleColor slots.
        $rgb = { param($hex) $r=[Convert]::ToInt32($hex.Substring(0,2),16); $g=[Convert]::ToInt32($hex.Substring(2,2),16); $b=[Convert]::ToInt32($hex.Substring(4,2),16); [uint32]($r -bor ($g -shl 8) -bor ($b -shl 16)) }
        $info.ColorTable[0]  = & $rgb '1E1E2E'  # Black       -> Base (background)
        $info.ColorTable[1]  = & $rgb '89B4FA'  # DarkBlue    -> Blue
        $info.ColorTable[2]  = & $rgb 'A6E3A1'  # DarkGreen   -> Green
        $info.ColorTable[3]  = & $rgb '94E2D5'  # DarkCyan    -> Teal
        $info.ColorTable[4]  = & $rgb 'F38BA8'  # DarkRed     -> Red
        $info.ColorTable[5]  = & $rgb 'CBA6F7'  # DarkMagenta -> Mauve
        $info.ColorTable[6]  = & $rgb 'F9E2AF'  # DarkYellow  -> Yellow
        $info.ColorTable[7]  = & $rgb 'CDD6F4'  # Gray        -> Text (foreground)
        $info.ColorTable[8]  = & $rgb '6C7086'  # DarkGray    -> Overlay0
        $info.ColorTable[9]  = & $rgb '89B4FA'  # Blue        -> Blue
        $info.ColorTable[10] = & $rgb 'A6E3A1'  # Green       -> Green
        $info.ColorTable[11] = & $rgb '89DCEB'  # Cyan        -> Sky
        $info.ColorTable[12] = & $rgb 'F38BA8'  # Red         -> Red
        $info.ColorTable[13] = & $rgb 'CBA6F7'  # Magenta     -> Mauve
        $info.ColorTable[14] = & $rgb 'F9E2AF'  # Yellow      -> Yellow
        $info.ColorTable[15] = & $rgb 'CDD6F4'  # White       -> Text
        # Workaround for the documented off-by-one shrink on Set*Ex.
        $info.srWindow.Right  += 1
        $info.srWindow.Bottom += 1
        [Win32Maint.ConsolePalette]::SetConsoleScreenBufferInfoEx($h, [ref]$info) | Out-Null
        $Host.UI.RawUI.BackgroundColor = 'Black'   # slot 0 = Base
        $Host.UI.RawUI.ForegroundColor = 'Gray'    # slot 7 = Text
        Clear-Host
    } catch {}
}
Set-CatppuccinConsole

# --- Console font size --------------------------------------
function Set-WMConsoleFont {
    param([int]$Size = 12, [string]$Face = 'Consolas')
    try {
        if (-not ('Win32Maint.ConsoleFont' -as [type])) {
            Add-Type -Namespace Win32Maint -Name ConsoleFont -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct COORD { public short X; public short Y; }
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct CONSOLE_FONT_INFOEX {
    public uint cbSize; public uint nFont; public COORD dwFontSize; public int FontFamily; public int FontWeight;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string FaceName;
}
[DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetCurrentConsoleFontEx(IntPtr h, bool max, ref CONSOLE_FONT_INFOEX f);
'@
        }
        $h = [Win32Maint.ConsoleFont]::GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        $info = New-Object Win32Maint.ConsoleFont+CONSOLE_FONT_INFOEX
        $info.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($info)
        $info.FontFamily = 54   # FF_MODERN | TMPF_TRUETYPE
        $info.FontWeight = 400
        $info.FaceName = $Face
        $coord = New-Object Win32Maint.ConsoleFont+COORD
        $coord.X = 0; $coord.Y = [short]$Size
        $info.dwFontSize = $coord
        [Win32Maint.ConsoleFont]::SetCurrentConsoleFontEx($h, $false, [ref]$info) | Out-Null
    } catch {}
}
Set-WMConsoleFont 12

# Decode native command output (e.g. winget) as UTF-8 so accented text is not
# mangled (process-wide static; also re-applied inside the worker runspace).
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# Output folder (predictable; hosted mode has no script dir).
$WMRoot = Join-Path $env:SystemDrive 'WinMaint'
if (-not (Test-Path $WMRoot)) { New-Item -ItemType Directory -Path $WMRoot -Force | Out-Null }
$LogFile       = Join-Path $WMRoot 'WinMaint.log'
$InventoryFile = Join-Path $WMRoot 'Inventory.csv'

# --- Shared state between UI thread and worker runspace -----
$sync = [hashtable]::Synchronized(@{})
$sync.Running    = $false
$sync.Status     = 'Ready'
$sync.LogFile    = $LogFile
$sync.Inventory  = $InventoryFile

# --- winget resolver (works in elevated session) ------------
function Resolve-WMWinget {
    # 1) The CURRENT user's App Execution Alias. Executing this 0-byte reparse
    #    point launches the packaged winget in this user's context - the supported
    #    way. Running the real winget.exe under WindowsApps directly is ACL-blocked
    #    ("Access denied"), so the alias is strongly preferred.
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path $alias) { return $alias }
    # 2) PATH lookup (works in a non-elevated session), but only accept a real
    #    alias/exe, never a path we cannot execute.
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) { return $cmd.Source }
    # Deliberately do NOT return the real winget.exe under Program Files\WindowsApps:
    # executing it directly is ACL-blocked ("Access denied"). Returning it here would
    # also make $Winget look "available" and suppress the auto-install. If no usable
    # alias exists, return $null so the caller installs winget (which creates the
    # current user's alias).
    return $null
}
$Winget = Resolve-WMWinget

# System manufacturer, used to show only the matching OEM tool in the UI.
$WMManufacturer = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer

# ============================================================
#  ENGINE FUNCTIONS  (run inside the worker runspace)
#  All write progress through Write-WMLog -> $sync.LogQueue.
# ============================================================
function Write-WMLog {
    param([string]$Text, [ValidateSet('plain','head','step','ok','warn','err')][string]$Level = 'plain')
    $prefix = switch ($Level) {
        'head' { "`r`n==== " }
        'step' { "  >> " }
        'ok'   { "  OK " }
        'warn' { "  !! " }
        'err'  { "  XX " }
        default { "     " }
    }
    $line = "$prefix$Text"
    $color = switch ($Level) { 'head' { 'Cyan' } 'step' { 'Yellow' } 'ok' { 'Green' } 'warn' { 'Magenta' } 'err' { 'Red' } default { 'Gray' } }
    Write-Host $line -ForegroundColor $color
    $sync.Status = $Text   # surfaced in the window status bar by the UI timer
    try { Add-Content -Path $sync.LogFile -Value ("[{0:HH:mm:ss}]{1}" -f (Get-Date), $line) -ErrorAction SilentlyContinue } catch {}
}

function Invoke-WMSystemSummary {
    Write-WMLog "SYSTEM SUMMARY" head
    try {
        $cs      = Get-CimInstance Win32_ComputerSystem
        $os      = Get-CimInstance Win32_OperatingSystem
        $bios    = Get-CimInstance Win32_BIOS
        $cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1
        $disks   = Get-CimInstance Win32_DiskDrive
        $ram     = Get-CimInstance Win32_PhysicalMemory
        $volumes = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

        $totalRAM   = [math]::Round(($cs.TotalPhysicalMemory / 1GB), 1)
        $winVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).DisplayVersion

        Write-WMLog "Hostname      : $($cs.Name)"
        Write-WMLog "Manufacturer  : $($cs.Manufacturer)"
        Write-WMLog "Model         : $($cs.Model)"
        Write-WMLog "Serial Number : $($bios.SerialNumber)"
        Write-WMLog "Windows       : $($os.Caption) (Version $winVersion, Build $($os.BuildNumber))"
        Write-WMLog "CPU           : $($cpu.Name.Trim())"
        Write-WMLog "Cores/Threads : $($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads"
        Write-WMLog "RAM           : $totalRAM GB ($($ram.Count) stick(s))"

        Write-WMLog "Disk Drives:"
        foreach ($disk in $disks) {
            $sizeGB = [math]::Round($disk.Size / 1GB, 1)
            $media  = if ($disk.MediaType) { $disk.MediaType } else { "Unknown" }
            Write-WMLog "  - $($disk.Model.Trim())  |  $sizeGB GB  |  $media  |  SMART: $($disk.Status)"
        }
        Write-WMLog "Disk Usage:"
        foreach ($vol in $volumes) {
            $totalGB = [math]::Round($vol.Size / 1GB, 1)
            $freeGB  = [math]::Round($vol.FreeSpace / 1GB, 1)
            $usedGB  = [math]::Round(($vol.Size - $vol.FreeSpace) / 1GB, 1)
            $pctFree = if ($vol.Size -gt 0) { [math]::Round(($vol.FreeSpace / $vol.Size) * 100, 0) } else { 0 }
            Write-WMLog "  $($vol.DeviceID)  $usedGB / $totalGB GB used  ($freeGB GB free, $pctFree% free)"
        }
        $nics = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        Write-WMLog "Network (active):"
        foreach ($nic in $nics) {
            $ip  = ($nic.IPAddress | Where-Object { $_ -match "\." } | Select-Object -First 1)
            if (-not $ip) { $ip = "N/A" }
            $mac = if ($nic.MACAddress) { $nic.MACAddress } else { "N/A" }
            Write-WMLog "  - $($nic.Description)  [IP: $ip, MAC: $mac]"
        }

        # Inventory CSV (overwrite each run)
        try {
            $diskInfo = ($disks | ForEach-Object {
                $m = if ($_.MediaType) { $_.MediaType } else { "Unknown" }
                "$($_.Model.Trim()) ($([math]::Round($_.Size/1GB,1)) GB, $m, SMART: $($_.Status))"
            }) -join "; "
            $volInfo = ($volumes | ForEach-Object {
                "$($_.DeviceID) $([math]::Round(($_.Size-$_.FreeSpace)/1GB,1))/$([math]::Round($_.Size/1GB,1)) GB ($([math]::Round($_.FreeSpace/1GB,1)) GB livres)"
            }) -join "; "
            $netInfo = ($nics | ForEach-Object {
                $i = ($_.IPAddress | Where-Object { $_ -match "\." } | Select-Object -First 1); if (-not $i) { $i = "N/A" }
                $mc = if ($_.MACAddress) { $_.MACAddress } else { "N/A" }
                "$($_.Description) [IP: $i, MAC: $mc]"
            }) -join "; "
            [PSCustomObject]@{
                Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Hostname = $cs.Name; Manufacturer = $cs.Manufacturer; Model = $cs.Model
                SerialNumber = $bios.SerialNumber
                Windows = "$($os.Caption) (Version $winVersion, Build $($os.BuildNumber))"
                CPU = $cpu.Name.Trim(); Cores = $cpu.NumberOfCores; Threads = $cpu.NumberOfLogicalProcessors
                RAM_GB = $totalRAM; RAM_Sticks = $ram.Count
                Disks = $diskInfo; Volumes = $volInfo; Network = $netInfo
            } | Export-Csv -Path $sync.Inventory -NoTypeInformation -Encoding UTF8
            Write-WMLog "Inventory written to $($sync.Inventory)" ok
        } catch { Write-WMLog "Could not write inventory: $_" warn }
    } catch { Write-WMLog "Could not retrieve system info: $_" warn }
}

function Invoke-WMRebootCheck {
    Write-WMLog "PENDING REBOOT CHECK" head
    $reasons = @()
    $cbsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $wuKey  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if (Test-Path $cbsKey) { $reasons += "Windows Component Servicing" }
    if (Test-Path $wuKey)  { $reasons += "Windows Update" }
    try {
        $pv = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction Stop
        if ($pv.PendingFileRenameOperations) { $reasons += "Pending File Rename Operations" }
    } catch {}
    if ($reasons.Count) {
        Write-WMLog "REBOOT PENDING for:" warn
        $reasons | ForEach-Object { Write-WMLog "  - $_" warn }
    } else { Write-WMLog "No pending reboot. Safe to proceed." ok }
}

function Invoke-WMStartupItems {
    Write-WMLog "STARTUP ITEMS" head
    $items = @()
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $e = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            if ($e) {
                $e.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
                    $items += [PSCustomObject]@{ Source = $path.Split("\")[-1]; Name = $_.Name; Command = $_.Value }
                }
            }
        }
    }
    foreach ($folder in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
                          "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
        if (Test-Path $folder) {
            Get-ChildItem $folder -ErrorAction SilentlyContinue | ForEach-Object {
                $items += [PSCustomObject]@{ Source = "Startup Folder"; Name = $_.Name; Command = $_.FullName }
            }
        }
    }
    if (-not $items.Count) { Write-WMLog "No startup items." ok }
    else {
        Write-WMLog "$($items.Count) startup item(s):"
        foreach ($i in $items) { Write-WMLog "  [$($i.Source)] $($i.Name) -> $($i.Command)" }
    }
}

function Invoke-WMEventLog {
    Write-WMLog "EVENT LOG CHECK (critical / useful, last 7 days)" head
    $since = (Get-Date).AddDays(-7)
    $txt = Join-Path (Split-Path $sync.LogFile) 'EventLog.txt'
    $collected = New-Object System.Collections.ArrayList

    # Critical (Level 1) events from System + Application.
    foreach ($log in @("System", "Application")) {
        try {
            Get-WinEvent -FilterHashtable @{ LogName = $log; Level = 1; StartTime = $since } -ErrorAction SilentlyContinue |
                ForEach-Object { [void]$collected.Add($_) }
        } catch {}
    }
    # Useful non-critical signals: unexpected shutdown (41), dirty shutdown (6008),
    # and bugcheck / BSoD (1001).
    try {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 6008, 1001; StartTime = $since } -ErrorAction SilentlyContinue |
            ForEach-Object { [void]$collected.Add($_) }
    } catch {}

    $events = $collected | Sort-Object TimeCreated -Descending
    if (-not $events -or $events.Count -eq 0) {
        Write-WMLog "No critical events in the last 7 days." ok
        "No critical events in the last 7 days (generated $(Get-Date))." | Set-Content -Path $txt -Encoding UTF8
        Write-WMLog "Report saved to $txt" ok
        return
    }

    Write-WMLog "$($events.Count) critical/relevant event(s) found:" warn
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("CW Maintenance Utility - Critical event report")
    [void]$sb.AppendLine("Generated: $(Get-Date)   Window: last 7 days")
    [void]$sb.AppendLine(("-" * 60))
    foreach ($ev in $events) {
        $lvl = switch ($ev.Level) { 1 { 'CRITICAL' } 2 { 'ERROR' } default { 'INFO' } }
        $head = "[$lvl] $($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm')) | $($ev.LogName) | $($ev.ProviderName) | Id $($ev.Id)"
        $msg = ($ev.Message -split "`n")[0].Trim()
        if ($msg.Length -gt 110) { $msg = $msg.Substring(0, 110) + "..." }
        Write-WMLog "  $head"
        if ($msg) { Write-WMLog "      $msg" }
        [void]$sb.AppendLine($head)
        [void]$sb.AppendLine("  $($ev.Message)")
        [void]$sb.AppendLine("")
    }
    try { $sb.ToString() | Set-Content -Path $txt -Encoding UTF8; Write-WMLog "Full report saved to $txt" ok }
    catch { Write-WMLog "Could not save report: $_" warn }
}

function Invoke-WMCleanup {
    Write-WMLog "CLEANUP (system drive only, silent)" head
    $sysDrive = $env:SystemDrive   # e.g. C:
    # All on C:; cleaned by direct deletion (no cleanmgr window).
    $tempPaths = @(
        $env:TEMP, $env:TMP, "$env:SystemRoot\Temp", "$env:LOCALAPPDATA\Temp",
        "$env:SystemRoot\Prefetch",
        "$env:SystemRoot\SoftwareDistribution\Download",
        "$env:ProgramData\Microsoft\Windows\DeliveryOptimization\Cache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"   # thumbnail/icon cache
    )
    [long]$totalFreed = 0
    foreach ($path in ($tempPaths | Sort-Object -Unique)) {
        if (-not (Test-Path $path)) { continue }
        # Safety: only ever clean paths on the system drive (C:).
        if (([System.IO.Path]::GetPathRoot($path)).TrimEnd('\') -ine $sysDrive) {
            Write-WMLog "Skipping (not on ${sysDrive}): $path" warn; continue
        }
        Write-WMLog "Cleaning: $path" step
        try {
            $size = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
            $totalFreed += $size
            Write-WMLog "Cleaned (~$([math]::Round($size/1MB,1)) MB)" ok
        } catch { Write-WMLog "Partial clean on ${path}: $_" warn }
    }
    # Recycle Bin (system drive), silent.
    try { Clear-RecycleBin -DriveLetter $sysDrive.TrimEnd(':') -Force -ErrorAction Stop; Write-WMLog "Recycle Bin emptied." ok }
    catch { Write-WMLog "Recycle Bin already empty or unavailable." }
    Write-WMLog "Total freed: ~$([math]::Round($totalFreed/1MB,1)) MB" ok
    Write-WMLog "Tip: for WinSxS store cleanup use Config > Fixes > 'Component Store Cleanup' (slow)."
}

# WinSxS component store cleanup - long and silent, so it lives on its own button.
function Invoke-WMComponentCleanup {
    Write-WMLog "COMPONENT STORE CLEANUP (DISM)" head
    Write-WMLog "This can take several minutes with little output - please wait..." step
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1 | ForEach-Object {
        $l = "$_".Trim(); if ($l -and $l -notmatch '%') { Write-WMLog $l }
    }
    Write-WMLog "Component store cleanup complete." ok
}

# --- winget helper ------------------------------------------
# Inside the worker runspace, winget's native stdout is swallowed by the
# PowerShell instance's pipeline, so we capture it and re-emit through Write-WMLog
# (console + file). We drop the block-character progress bars and spinner frames
# so we keep useful status (Downloading / Successfully installed) without "walls".
# Uniform runner for native commands (winget / sfc / DISM ...). Captures output
# and logs only meaningful text, dropping carriage-return progress bars, spinner
# frames and bare percentage lines so the themed console stays clean (no "walls",
# no colored progress blocks).
function Invoke-WMConsole {
    param([string]$File, [string[]]$Arguments)
    $blockRe = '[' + [char]0x2580 + '-' + [char]0x259F + ']'
    & $File @Arguments 2>&1 | ForEach-Object {
        $l = ("$_").Trim()
        if (-not $l) { return }
        if ($l -match $blockRe)       { return }   # progress bar frames
        if ($l -match '^[-\\|/]+$')   { return }   # spinner frames
        if ($l -match '%')            { return }   # percentage progress lines
        Write-WMLog $l
    }
}

function Invoke-WMWinget {
    param([string[]]$A)
    Invoke-WMConsole $Winget $A
}

# True if a winget package id is already installed on the machine.
function Test-WMInstalled {
    param([string]$Id)
    if (-not $Winget) { return $false }
    $listed = & $Winget list --id $Id --accept-source-agreements 2>&1 | Out-String
    return ($listed -match [regex]::Escape($Id))
}

# True if a program with a matching display name is installed (ARP registry or Appx).
# More reliable than a winget id when the installed package id differs.
function Test-WMInstalledName {
    param([string]$NamePattern)
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($k in $keys) {
        if (Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $NamePattern }) { return $true }
    }
    if (Get-AppxPackage -Name $NamePattern -ErrorAction SilentlyContinue) { return $true }
    return $false
}

# Launch a program in the logged-in user's (non-elevated) session via a one-shot
# scheduled task. Needed because this script runs elevated, and some apps (e.g.
# HP Support Assistant) won't show their window when started from an admin process.
function Start-WMAsUser {
    param([string]$Path, [string]$Arguments = "")
    $user = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if (-not $user) { return $false }
    $taskName = "WMLaunch_" + [guid]::NewGuid().ToString("N").Substring(0, 8)
    try {
        $action = if ($Arguments) {
            New-ScheduledTaskAction -Execute $Path -Argument $Arguments -WorkingDirectory (Split-Path $Path)
        } else {
            New-ScheduledTaskAction -Execute $Path -WorkingDirectory (Split-Path $Path)
        }
        $principal = New-ScheduledTaskPrincipal -UserId $user -RunLevel Limited
        $task = New-ScheduledTask -Action $action -Principal $principal
        Register-ScheduledTask -TaskName $taskName -InputObject $task -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        Start-Sleep -Seconds 3
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        return $true
    } catch {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        return $false
    }
}

# Launch an installed desktop app via its Start Menu shortcut (by name pattern).
function Start-WMShortcut {
    param([string]$NamePattern)
    $dirs = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    )
    $lnk = $dirs |
        ForEach-Object { Get-ChildItem $_ -Recurse -Filter '*.lnk' -ErrorAction SilentlyContinue } |
        Where-Object { $_.BaseName -like $NamePattern } |
        Select-Object -First 1
    if ($lnk) { Start-Process $lnk.FullName; return $true }
    return $false
}

# --- Install (winget) ---------------------------------------
function Install-WMApp {
    param($App)
    $Id = $App.WingetId; $Name = $App.Label
    if (-not $Winget) { Write-WMLog "winget unavailable; cannot install $Name." warn; return }
    Write-WMLog "Checking/installing: $Name ($Id)" step
    $listArgs = @('list', '--id', $Id, '--accept-source-agreements')
    if ($App.Source) { $listArgs += @('--source', $App.Source) }
    $listed = & $Winget @listArgs 2>&1 | Out-String
    if ($listed -match [regex]::Escape($Id)) { Write-WMLog "$Name is already installed." ok; return }
    $instArgs = @('install', '--id', $Id, '--accept-package-agreements', '--accept-source-agreements', '--silent')
    if ($App.Source) { $instArgs += @('--source', $App.Source) }
    Invoke-WMWinget $instArgs
    $code = $LASTEXITCODE
    if ($null -eq $code -or $code -eq 0) { Write-WMLog "${Name}: installed." ok }
    else { Write-WMLog "${Name}: winget returned exit code $code (may have failed)." warn }
}

# --- Uninstall (winget) -------------------------------------
function Invoke-WMUninstallApp {
    param($App)
    $Id = $App.WingetId; $Name = $App.Label
    if (-not $Winget) { Write-WMLog "winget unavailable; cannot uninstall $Name." warn; return }
    Write-WMLog "Checking/uninstalling: $Name ($Id)" step
    $listArgs = @('list', '--id', $Id, '--accept-source-agreements')
    if ($App.Source) { $listArgs += @('--source', $App.Source) }
    $listed = & $Winget @listArgs 2>&1 | Out-String
    if ($listed -notmatch [regex]::Escape($Id)) { Write-WMLog "$Name is not installed." ok; return }
    Invoke-WMWinget @('uninstall', '--id', $Id, '--accept-source-agreements', '--silent')
    $code = $LASTEXITCODE
    if ($null -eq $code -or $code -eq 0) { Write-WMLog "${Name}: uninstalled." ok }
    else { Write-WMLog "${Name}: winget returned exit code $code (may have failed)." warn }
}

# --- Updates -------------------------------------------------
function Invoke-WMWindowsUpdate {
    Write-WMLog "WINDOWS UPDATE" head
    # Primary: the built-in COM API, installing update-by-update so progress is
    # visible (download/install per title) instead of a silent wait.
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        Write-WMLog "Searching for updates..." step
        $res = $session.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software'")
        $tot = $res.Updates.Count
        if ($tot -eq 0) { Write-WMLog "Windows is up to date." ok; return }
        Write-WMLog "$tot update(s) found:" step
        for ($i = 0; $i -lt $tot; $i++) { Write-WMLog "  - $($res.Updates.Item($i).Title)" }
        for ($i = 0; $i -lt $tot; $i++) {
            $u = $res.Updates.Item($i)
            if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
            $coll = New-Object -ComObject Microsoft.Update.UpdateColl
            $coll.Add($u) | Out-Null
            Write-WMLog "[$($i + 1)/$tot] Downloading: $($u.Title)" step
            $dl = $session.CreateUpdateDownloader(); $dl.Updates = $coll; $dl.Download() | Out-Null
            Write-WMLog "[$($i + 1)/$tot] Installing: $($u.Title)" step
            $ins = $session.CreateUpdateInstaller(); $ins.Updates = $coll
            $r = $ins.Install()
            $st = if ($r.ResultCode -eq 2) { 'installed' } else { "result code $($r.ResultCode)" }
            Write-WMLog "[$($i + 1)/$tot] $($u.Title) -> $st" ok
        }
        Write-WMLog "Windows Update complete. A reboot may be required." ok
    } catch {
        Write-WMLog "COM update failed ($_); trying PSWindowsUpdate..." warn
        try {
            if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) { Install-Module PSWindowsUpdate -Force -Scope AllUsers -ErrorAction Stop }
            Import-Module PSWindowsUpdate -ErrorAction Stop
            Install-WindowsUpdate -AcceptAll -IgnoreReboot -AutoReboot:$false -Verbose 4>&1 |
                ForEach-Object { $l = "$_".Trim(); if ($l) { Write-WMLog $l } }
            Write-WMLog "Updates installed. A reboot may be required." ok
        } catch { Write-WMLog "Windows Update failed: $_" err }
    }
}

function Invoke-WMStoreUpdate {
    Write-WMLog "MICROSOFT STORE UPDATES" head
    try {
        $obj = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" -ErrorAction Stop
        Invoke-CimMethod -InputObject $obj -MethodName UpdateScanMethod | Out-Null
        Write-WMLog "Store update scan triggered." ok
    } catch {
        Write-WMLog "MDM bridge unavailable; trying winget..." warn
        if ($Winget) {
            Invoke-WMWinget @('upgrade', '--source', 'msstore', '--all', '--accept-package-agreements', '--accept-source-agreements', '--silent')
            Write-WMLog "Store apps updated via winget." ok
        } else { Write-WMLog "winget unavailable." err }
    }
}

function Invoke-WMOfficeUpdate {
    Write-WMLog "MICROSOFT OFFICE UPDATES" head
    $c2r = @(
        "${env:ProgramFiles}\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe",
        "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($c2r) {
        Write-WMLog "Running Click-to-Run updater..." step
        Start-Process -FilePath $c2r -ArgumentList "/update user displaylevel=false forceappshutdown=false" -Wait
        Write-WMLog "Office update check complete." ok
    } else {
        Write-WMLog "Office C2R not found; trying winget..." warn
        if ($Winget) {
            Invoke-WMWinget @('upgrade', '--id', 'Microsoft.Office', '--accept-package-agreements', '--accept-source-agreements', '--silent')
            Write-WMLog "Office updated via winget." ok
        }
    }
}

function Invoke-WMWingetUpgradeAll {
    Write-WMLog "WINGET - UPGRADE ALL" head
    if (-not $Winget) { Write-WMLog "winget unavailable." err; return }
    Invoke-WMWinget @('upgrade', '--all', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown')
    Write-WMLog "winget upgrade complete." ok
}

function Invoke-WMLenovoVantage {
    Write-WMLog "LENOVO VANTAGE" head
    $mfr = (Get-CimInstance Win32_ComputerSystem).Manufacturer
    if ($mfr -notmatch "Lenovo") { Write-WMLog "Manufacturer '$mfr' - skipped (Lenovo only)." warn; return }
    if (-not $Winget) { Write-WMLog "winget unavailable." warn; return }
    # Lenovo Vantage is a UWP app; detect via Appx package.
    $pkg = Get-AppxPackage -Name "*LenovoCompanion*" -ErrorAction SilentlyContinue
    if (-not $pkg) { $pkg = Get-AppxPackage -Name "*LenovoVantage*" -ErrorAction SilentlyContinue }
    if ($pkg) {
        Write-WMLog "Lenovo Vantage is already installed." ok
    } else {
        Invoke-WMWinget @('install', '--id', '9WZDNCRFJ4MV', '--source', 'msstore', '--accept-package-agreements', '--accept-source-agreements')
        Start-Sleep -Seconds 8
        $pkg = Get-AppxPackage -Name "*LenovoCompanion*" -ErrorAction SilentlyContinue
        if (-not $pkg) { $pkg = Get-AppxPackage -Name "*LenovoVantage*" -ErrorAction SilentlyContinue }
        Write-WMLog "Lenovo Vantage installed." ok
    }
    if ($pkg) {
        Start-Process "explorer.exe" -ArgumentList "shell:AppsFolder\$($pkg.PackageFamilyName)!App"
        Write-WMLog "Lenovo Vantage launched." ok
    } else { Write-WMLog "Installed, but could not launch automatically; open it from the Start Menu." warn }
}

function Invoke-WMHPSupport {
    Write-WMLog "HP SUPPORT ASSISTANT" head
    $mfr = (Get-CimInstance Win32_ComputerSystem).Manufacturer
    if ($mfr -notmatch "HP|Hewlett") { Write-WMLog "Manufacturer '$mfr' - skipped (HP only)." warn; return }
    if (-not $Winget) { Write-WMLog "winget unavailable." warn; return }
    # The HP Support Assistant UI is opened by HPSALauncher.exe (under
    # ...\HP Support Framework\Resources\); prefer it over HPSAAppLauncher.exe.
    $findHpExe = {
        Get-ChildItem -Path "$env:ProgramFiles\HP", "${env:ProgramFiles(x86)}\HP",
                            "$env:ProgramFiles\Hewlett-Packard", "${env:ProgramFiles(x86)}\Hewlett-Packard" `
                       -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(HPSALauncher|HPSAAppLauncher)\.exe$' } |
            Sort-Object { $_.Name -ne 'HPSALauncher.exe' } |
            Select-Object -First 1
    }
    # Presence of the launcher exe is the most reliable "installed" signal here:
    # under an elevated session the per-user registry/Appx checks can miss it.
    $hpExe = & $findHpExe
    if ($hpExe -or (Test-WMInstalledName "*HP Support Assistant*")) {
        Write-WMLog "HP Support Assistant is already installed." ok
    } else {
        Invoke-WMWinget @('install', '--id', 'HPInc.HPSupportAssistant', '--accept-package-agreements', '--accept-source-agreements', '--silent')
        Start-Sleep -Seconds 5
        $hpExe = & $findHpExe
        Write-WMLog "HP Support Assistant installed." ok
    }
    # HP Support Assistant is the UWP app; launch it by its real AUMID from
    # Get-StartApps (the app id is NOT "App"), via explorer so it opens in the
    # user session. The desktop HPSALauncher.exe belongs to the old framework and
    # does not show the window, so it is only a fallback.
    $aumid = (Get-StartApps -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*HP Support Assistant*" } | Select-Object -First 1).AppID
    if ($aumid) { Start-Process "explorer.exe" -ArgumentList "shell:AppsFolder\$aumid"; Write-WMLog "HP Support Assistant launched." ok }
    elseif ($hpExe -and (Start-WMAsUser $hpExe.FullName)) { Write-WMLog "HP Support Assistant launched ($($hpExe.Name))." ok }
    elseif (Start-WMShortcut "*HP Support Assistant*") { Write-WMLog "HP Support Assistant launched." ok }
    else { Write-WMLog "Installed, but could not locate the launcher; open it from the Start Menu." warn }
}

function Invoke-WMDellCommandUpdate {
    Write-WMLog "DELL COMMAND | UPDATE" head
    $mfr = (Get-CimInstance Win32_ComputerSystem).Manufacturer
    if ($mfr -notmatch "Dell") { Write-WMLog "Manufacturer '$mfr' - skipped (Dell only)." warn; return }
    if (-not $Winget) { Write-WMLog "winget unavailable." warn; return }
    if (Test-WMInstalledName "*Dell Command*Update*") {
        Write-WMLog "Dell Command | Update is already installed." ok
    } else {
        Invoke-WMWinget @('install', '--id', 'Dell.CommandUpdate', '--accept-package-agreements', '--accept-source-agreements', '--silent')
        Start-Sleep -Seconds 5
        Write-WMLog "Dell Command | Update installed." ok
    }
    $dcuExe = @(
        "${env:ProgramFiles}\Dell\CommandUpdate\DellCommandUpdate.exe",
        "${env:ProgramFiles(x86)}\Dell\CommandUpdate\DellCommandUpdate.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($dcuExe) { Start-Process $dcuExe; Write-WMLog "Dell Command | Update launched." ok }
    elseif (Start-WMShortcut "*Dell Command*Update*") { Write-WMLog "Dell Command | Update launched." ok }
    else { Write-WMLog "Installed, but could not launch automatically; open it from the Start Menu." warn }
}

function Invoke-WMIntelDSA {
    Write-WMLog "INTEL DRIVER & SUPPORT ASSISTANT" head
    if (-not $Winget) { Write-WMLog "winget unavailable." warn; return }
    if (Test-WMInstalled 'Intel.IntelDriverAndSupportAssistant') {
        Write-WMLog "Intel DSA is already installed." ok
    } else {
        Invoke-WMWinget @('install', '--id', 'Intel.IntelDriverAndSupportAssistant', '--accept-package-agreements', '--accept-source-agreements', '--silent')
        Write-WMLog "Intel DSA installed." ok
    }
    $iExe = Get-ChildItem -Path "$env:ProgramFiles\Intel", "${env:ProgramFiles(x86)}\Intel" -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(DSATray|DSAExt|DSA|Esrv)\.exe$' } | Select-Object -First 1
    if ($iExe) { Start-Process $iExe.FullName; Write-WMLog "Intel DSA launched ($($iExe.Name))." ok }
    elseif (Start-WMShortcut "*Intel*Driver*Support Assistant*") { Write-WMLog "Intel DSA launched." ok }
    else {
        # Intel DSA is agent + browser based; open its scan page via explorer so the
        # URL resolves in the user's default browser (Start-Process <url> can throw
        # "no application associated" from an elevated session).
        try { Start-Process explorer.exe 'https://www.intel.com/content/www/us/en/support/detect.html'; Write-WMLog "Opened Intel DSA scan page in the browser." ok }
        catch { Write-WMLog "Installed. Open 'Intel Driver & Support Assistant' from the Start Menu." warn }
    }
}

# --- Tweaks (data-driven, reversible) -----------------------
# Each tweak item carries the registry values for its on/off state and an
# optional list of services to disable. Apply sets the "on" state; undo sets
# the "off" (Windows default) state.
function Invoke-WMTweak {
    param($T, [string]$Mode)
    $apply = ($Mode -ne 'undo')
    Write-WMLog "$($T.Label) [$Mode]" step
    foreach ($r in $T.Reg) {
        $val = if ($apply) { $r.On } else { $r.Off }
        try {
            if (-not (Test-Path $r.Path)) { New-Item -Path $r.Path -Force | Out-Null }
            Set-ItemProperty -Path $r.Path -Name $r.Name -Value $val -Type $r.Kind -Force -ErrorAction Stop
        } catch { Write-WMLog "  reg $($r.Path)\$($r.Name): $_" warn }
    }
    foreach ($svc in $T.SvcOff) {
        try {
            if ($apply) { Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue; Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue }
            else        { Set-Service -Name $svc -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name $svc -ErrorAction SilentlyContinue }
        } catch { Write-WMLog "  service ${svc}: $_" warn }
    }
    # Optional script bodies (for tweaks that aren't pure registry/service).
    $scr = if ($apply) { $T.ApplyScript } else { $T.UndoScript }
    if ($scr) { try { Invoke-Expression $scr } catch { Write-WMLog "  script: $_" warn } }
    Write-WMLog "$($T.Label): $(if ($apply) {'applied'} else {'reverted'})." ok
}

# --- Config: Windows optional features (DISM) ---------------
function Invoke-WMFeature {
    param($F, [string]$Mode)
    $apply = ($Mode -ne 'undo')
    Write-WMLog "$($F.Label) [$Mode]" step
    foreach ($name in $F.Feature) {
        try {
            if ($apply) { Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart -ErrorAction Stop | Out-Null }
            else        { Disable-WindowsOptionalFeature -Online -FeatureName $name -NoRestart -ErrorAction Stop | Out-Null }
        } catch { Write-WMLog "  feature ${name}: $_" warn }
    }
    Write-WMLog "$($F.Label): $(if ($apply) {'enabled'} else {'disabled'}). Reboot may be required." ok
}

# --- Config: Fixes ------------------------------------------
function Invoke-WMSfcDism {
    Write-WMLog "SYSTEM CORRUPTION SCAN (SFC + DISM)" head
    Write-WMLog "Running sfc /scannow..." step
    Invoke-WMConsole 'sfc.exe' @('/scannow')
    Write-WMLog "Running DISM /RestoreHealth..." step
    Invoke-WMConsole 'DISM.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth')
    Write-WMLog "System corruption scan complete." ok
}

function Invoke-WMNetworkReset {
    Write-WMLog "NETWORK RESET" head
    Write-WMLog "winsock + IP reset, flushing DNS..." step
    Invoke-WMConsole 'netsh.exe' @('winsock', 'reset')
    Invoke-WMConsole 'netsh.exe' @('int', 'ip', 'reset')
    Invoke-WMConsole 'ipconfig.exe' @('/flushdns')
    Write-WMLog "Network stack reset. Reboot recommended." ok
}

function Invoke-WMWUReset {
    Write-WMLog "WINDOWS UPDATE RESET" head
    try {
        Write-WMLog "Stopping update services..." step
        'wuauserv', 'cryptSvc', 'bits', 'msiserver' | ForEach-Object { Stop-Service -Name $_ -Force -ErrorAction SilentlyContinue }
        $ts = Get-Date -Format 'yyyyMMddHHmmss'
        Rename-Item "$env:SystemRoot\SoftwareDistribution" "SoftwareDistribution.$ts" -ErrorAction SilentlyContinue
        Rename-Item "$env:SystemRoot\System32\catroot2" "catroot2.$ts" -ErrorAction SilentlyContinue
        Write-WMLog "Restarting update services..." step
        'wuauserv', 'cryptSvc', 'bits', 'msiserver' | ForEach-Object { Start-Service -Name $_ -ErrorAction SilentlyContinue }
        Write-WMLog "Windows Update components reset." ok
    } catch { Write-WMLog "Windows Update reset failed: $_" err }
}

function Invoke-WMWingetReinstall {
    Write-WMLog "INSTALL / UPDATE WINGET (App Installer)" head
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $ProgressPreference = 'SilentlyContinue'

    # Primary: download the App Installer bundle + dependencies directly (light,
    # no PowerShell module install).
    $tmp = $env:TEMP
    try {
        Write-WMLog "Downloading VCLibs dependency..." step
        $vclibs = Join-Path $tmp 'Microsoft.VCLibs.x64.14.00.Desktop.appx'
        Invoke-WebRequest 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $vclibs -UseBasicParsing -ErrorAction Stop
        Add-AppxPackage $vclibs -ErrorAction SilentlyContinue

        Write-WMLog "Downloading UI.Xaml dependency..." step
        $nupkg = Join-Path $tmp 'uixaml.zip'; $xdir = Join-Path $tmp 'uixaml'
        Invoke-WebRequest 'https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6' -OutFile $nupkg -UseBasicParsing -ErrorAction Stop
        if (Test-Path $xdir) { Remove-Item $xdir -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive $nupkg $xdir -Force
        $xaml = Get-ChildItem (Join-Path $xdir 'tools\AppX\x64\Release') -Filter *.appx -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($xaml) { Add-AppxPackage $xaml.FullName -ErrorAction SilentlyContinue }

        Write-WMLog "Downloading the latest winget (App Installer)..." step
        $bundle = Join-Path $tmp 'winget.msixbundle'
        Invoke-WebRequest 'https://aka.ms/getwinget' -OutFile $bundle -UseBasicParsing -ErrorAction Stop
        Add-AppxPackage $bundle -ErrorAction Stop
        # Provision machine-wide so the elevated (admin) session can execute winget
        # even when the interactive user differs.
        try {
            $deps = @($vclibs); if ($xaml) { $deps += $xaml.FullName }
            Add-AppxProvisionedPackage -Online -PackagePath $bundle -DependencyPackagePath $deps -SkipLicense -ErrorAction Stop | Out-Null
        } catch { Write-WMLog "  (machine-wide provisioning skipped: $_)" warn }
        if (Resolve-WMWinget) { Write-WMLog "winget installed." ok; return }
        Write-WMLog "Bundle installed but winget still not resolved; trying module method..." warn
    } catch {
        Write-WMLog "Direct download failed ($_); trying the official module method..." warn
    }

    # Fallback: the official Microsoft.WinGet.Client module (same as WinUtil).
    try {
        Write-WMLog "Installing NuGet provider + Microsoft.WinGet.Client module..." step
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -ErrorAction Stop
        Write-WMLog "Running Repair-WinGetPackageManager..." step
        Repair-WinGetPackageManager -AllUsers -Latest -ErrorAction Stop
        Write-WMLog "winget installed/updated." ok
    } catch {
        Write-WMLog "Automatic install failed: $_" err
        Write-WMLog "Opening App Installer in the Microsoft Store..." step
        Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
    }
}

function Invoke-WMEnableNtp {
    Write-WMLog "ENABLE TIME SYNC (NTP)" head
    sc.exe config w32time start= auto 2>&1 | Out-Null
    Start-Service w32time -ErrorAction SilentlyContinue
    w32tm /resync 2>&1 | ForEach-Object { $l = "$_".Trim(); if ($l) { Write-WMLog $l } }
    Write-WMLog "Time sync enabled." ok
}

function Invoke-WMRestorePoint {
    Write-WMLog "CREATE SYSTEM RESTORE POINT" head
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Allow more than one restore point per 24h (default throttle).
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Checkpoint-Computer -Description "WinMaint $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-WMLog "Restore point created." ok
    } catch { Write-WMLog "Could not create restore point (System Protection may be off): $_" err }
}

function Invoke-WMRestartExplorer {
    Write-WMLog "RESTART EXPLORER" head
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Write-WMLog "Explorer restarted." ok
}

function Invoke-WMOpenReports {
    Write-WMLog "OPEN REPORTS FOLDER" head
    $folder = Split-Path $sync.LogFile
    Start-Process explorer.exe -ArgumentList $folder
    Write-WMLog "Opened $folder" ok
}

function Invoke-WMEnableOpenSSH {
    Write-WMLog "ENABLE OPENSSH SERVER" head
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop | Out-Null
        Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service sshd -ErrorAction SilentlyContinue
        Write-WMLog "OpenSSH Server enabled and started." ok
    } catch { Write-WMLog "Could not enable OpenSSH Server: $_" err }
}

# --- Debloat: remove preinstalled UWP apps (apply-only) -----
function Invoke-WMDebloat {
    param($D)
    Write-WMLog "Remove: $($D.Label)" step
    foreach ($n in $D.Appx) {
        try {
            Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $n } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        } catch { Write-WMLog "  ${n}: $_" warn }
    }
    Write-WMLog "$($D.Label): removed." ok
}

# --- Config: DNS -------------------------------------------
function Set-WMDns {
    param([string]$Primary, [string]$Secondary, [string]$Label)
    Write-WMLog "SET DNS -> $Label" head
    $nics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
    foreach ($n in $nics) {
        try {
            if ($Primary) { Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ServerAddresses $Primary, $Secondary -ErrorAction Stop }
            else { Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ResetServerAddresses -ErrorAction Stop }
            Write-WMLog "  $($n.Name): $Label" ok
        } catch { Write-WMLog "  $($n.Name): $_" warn }
    }
    ipconfig /flushdns | Out-Null
}
function Invoke-WMDnsCloudflare { Set-WMDns '1.1.1.1' '1.0.0.1' 'Cloudflare (1.1.1.1)' }
function Invoke-WMDnsGoogle     { Set-WMDns '8.8.8.8' '8.8.4.4' 'Google (8.8.8.8)' }
function Invoke-WMDnsQuad9       { Set-WMDns '9.9.9.9' '149.112.112.112' 'Quad9 (9.9.9.9)' }
function Invoke-WMDnsAuto        { Set-WMDns $null $null 'Automatic (DHCP)' }

# --- Config: Legacy panels (open built-in tools) ------------
function Invoke-WMPanel {
    param([string]$What)
    switch ($What) {
        'control'   { Start-Process control.exe }
        'ncpa'      { Start-Process control.exe -ArgumentList 'ncpa.cpl' }
        'powercfg'  { Start-Process control.exe -ArgumentList 'powercfg.cpl' }
        'mmsys'     { Start-Process control.exe -ArgumentList 'mmsys.cpl' }
        'sysdm'     { Start-Process control.exe -ArgumentList 'sysdm.cpl' }
        'devmgmt'   { Start-Process devmgmt.msc }
        'compmgmt'  { Start-Process compmgmt.msc }
        'services'  { Start-Process services.msc }
        'cleanmgr'  { Start-Process cleanmgr.exe }
        'printers'  { Start-Process explorer.exe -ArgumentList 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}' }  # legacy Devices and Printers
    }
}
function Invoke-WMControlPanel    { Invoke-WMPanel 'control';  Write-WMLog "Opened Control Panel." ok }
function Invoke-WMPrintersPanel   { Invoke-WMPanel 'printers'; Write-WMLog "Opened Devices and Printers." ok }
function Invoke-WMNetworkPanel    { Invoke-WMPanel 'ncpa';     Write-WMLog "Opened Network Connections." ok }
function Invoke-WMPowerPanel      { Invoke-WMPanel 'powercfg'; Write-WMLog "Opened Power Options." ok }
function Invoke-WMSoundPanel      { Invoke-WMPanel 'mmsys';    Write-WMLog "Opened Sound Settings." ok }
function Invoke-WMSystemPanel     { Invoke-WMPanel 'sysdm';    Write-WMLog "Opened System Properties." ok }
function Invoke-WMDeviceManager   { Invoke-WMPanel 'devmgmt';  Write-WMLog "Opened Device Manager." ok }
function Invoke-WMComputerMgmt    { Invoke-WMPanel 'compmgmt'; Write-WMLog "Opened Computer Management." ok }
function Invoke-WMServicesPanel   { Invoke-WMPanel 'services'; Write-WMLog "Opened Services." ok }

# --- Standard Maintenance: open CrystalDiskInfo -------------
# Open a tool: find its exe under Program Files; if missing, install via winget, then launch.
function Invoke-WMOpenApp {
    param($A)
    Write-WMLog "OPEN: $($A.Label)" head
    $find = {
        Get-ChildItem -Path "$env:ProgramFiles", "${env:ProgramFiles(x86)}" -Recurse -Depth 4 -Filter '*.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $A.ExeMatch } | Select-Object -First 1
    }
    $exe = & $find
    if (-not $exe -and $Winget -and $A.WingetId) {
        Write-WMLog "Not found; installing $($A.Label)..." step
        Invoke-WMWinget @('install', '--id', $A.WingetId, '--accept-package-agreements', '--accept-source-agreements', '--silent')
        Start-Sleep -Seconds 3
        $exe = & $find
    }
    if ($exe) { Start-Process $exe.FullName; Write-WMLog "$($A.Label) opened ($($exe.Name))." ok }
    else { Write-WMLog "Could not locate $($A.Label). Install it from the Install tab." warn }
}

function Invoke-WMDefenderQuick {
    Write-WMLog "WINDOWS DEFENDER - QUICK SCAN" head
    try { Start-MpScan -ScanType QuickScan -ErrorAction Stop; Write-WMLog "Quick scan complete." ok }
    catch { Write-WMLog "Defender scan failed: $_" err }
}
function Invoke-WMDefenderFull {
    Write-WMLog "WINDOWS DEFENDER - FULL SCAN" head
    Write-WMLog "Full scan can take a long time; the window stays responsive..." step
    try { Start-MpScan -ScanType FullScan -ErrorAction Stop; Write-WMLog "Full scan complete." ok }
    catch { Write-WMLog "Defender scan failed: $_" err }
}

function Invoke-WMCreateAdmin {
    Write-WMLog "CREATE LOCAL ADMINISTRATOR (itadmin)" head
    $u = 'itadmin'
    $plain = if ($sync.AdminPw) { $sync.AdminPw } else { 'itadmin' }
    $pw = ConvertTo-SecureString $plain -AsPlainText -Force
    try {
        if (Get-LocalUser -Name $u -ErrorAction SilentlyContinue) {
            Set-LocalUser -Name $u -Password $pw -ErrorAction Stop
            Write-WMLog "User '$u' already exists; password reset." ok
        } else {
            New-LocalUser -Name $u -Password $pw -FullName 'IT Admin' -Description 'Local admin (WinMaint)' -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop | Out-Null
            Write-WMLog "User '$u' created." ok
        }
        # Administrators group name is localized; resolve it by well-known SID.
        $grp = (Get-LocalGroup -SID 'S-1-5-32-544' -ErrorAction Stop).Name
        if (-not (Get-LocalGroupMember -Group $grp -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*\$u" })) {
            Add-LocalGroupMember -Group $grp -Member $u -ErrorAction Stop
        }
        Write-WMLog "'$u' is a member of '$grp'." ok
    } catch { Write-WMLog "Could not create local admin: $_" err }
}

# --- Supremo deploy (per client) ----------------------------
# Downloads Supremo.exe (hosted in the repo) to C:\WinMaint, then runs the
# unattended /deploy with the selected client's password + group id.
function Invoke-WMSupremoDeploy {
    param($C)
    Write-WMLog "SUPREMO DEPLOY: $($C.Label)" head
    $token = 'HSiymjaFA9WAfYtmW_wzk3J9S2SwTEav3xsgoWPYTwidK4dQSnygfW9iPjk9'
    $settingsPw = 'Q1dAVGVzdGUxMjMj'
    $exe = Join-Path (Split-Path $sync.LogFile) 'Supremo.exe'
    if (-not (Test-Path $exe)) {
        Write-WMLog "Downloading Supremo.exe..." step
        try { Invoke-WebRequest 'https://raw.githubusercontent.com/zzalyf/winmaint/main/Supremo.exe' -OutFile $exe -UseBasicParsing -ErrorAction Stop }
        catch { Write-WMLog "Could not download Supremo.exe: $_" err; return }
    }
    $a = @(
        '/deploy', '/execute',
        '/SetTokenAndPasswordBase64', $token, $C.PwB64,
        '/ConsoleNameWithGroupId', '#COMPUTERNAME#', $C.GroupId,
        '/OverwriteSettingsPasswordBase64', $settingsPw,
        '/OverwriteLanguage', 'pt',
        '/ProfessionalLogin', '0',
        '/OverwriteRunAsSystem', '1',
        '/OverwriteAskAuthorization', '1',
        '/OverwriteDisplayRequestFor', '30',
        '/OverwriteAllowAfterRequest', '1',
        '/OverwriteAutoUpdate', '0',
        '/OverWriteRandomPasswordLength', '0'
    )
    Write-WMLog "Deploying Supremo for $($C.Label) (unattended)..." step
    Start-Process -FilePath $exe -ArgumentList $a -Wait
    Write-WMLog "Supremo deploy executed for $($C.Label). It runs as a system service." ok
}

# ============================================================
#  CONFIG  -  drives the checkboxes per tab.
#  Key = unique id, Label = UI text, Action = engine function,
#  Default = checked by default. (Phase 1: Diagnostics + Cleanup.)
# ============================================================
$Config = [ordered]@{
    Install = @(
        # Browsers
        @{ Type = 'app'; Category = 'Browsers'; Label = 'Brave';              WingetId = 'Brave.Brave' }
        @{ Type = 'app'; Category = 'Browsers'; Label = 'Google Chrome';      WingetId = 'Google.Chrome' }
        @{ Type = 'app'; Category = 'Browsers'; Label = 'Microsoft Edge';     WingetId = 'Microsoft.Edge' }
        @{ Type = 'app'; Category = 'Browsers'; Label = 'Mozilla Firefox';    WingetId = 'Mozilla.Firefox' }
        # Communications
        @{ Type = 'app'; Category = 'Communications'; Label = 'Microsoft Teams'; WingetId = 'Microsoft.Teams' }
        @{ Type = 'app'; Category = 'Communications'; Label = 'WhatsApp';         WingetId = '9NKSQGP7F2NH'; Source = 'msstore' }
        @{ Type = 'app'; Category = 'Communications'; Label = 'Telegram';         WingetId = 'Telegram.TelegramDesktop' }
        # Development
        @{ Type = 'app'; Category = 'Development'; Label = 'VS Code';              WingetId = 'Microsoft.VisualStudioCode' }
        @{ Type = 'app'; Category = 'Development'; Label = 'Visual Studio 2026';   WingetId = 'Microsoft.VisualStudio.Community' }
        @{ Type = 'app'; Category = 'Development'; Label = 'Python 3';             WingetId = 'Python.Python.3.13' }
        @{ Type = 'app'; Category = 'Development'; Label = 'Node.js (LTS)';        WingetId = 'OpenJS.NodeJS.LTS' }
        # Microsoft Tools
        @{ Type = 'app'; Category = 'Microsoft Tools'; Label = 'PowerShell 7';              WingetId = 'Microsoft.PowerShell' }
        @{ Type = 'app'; Category = 'Microsoft Tools'; Label = 'OneDrive';                 WingetId = 'Microsoft.OneDrive' }
        @{ Type = 'app'; Category = 'Microsoft Tools'; Label = 'DISMTools';                WingetId = 'CodingWondersSoftware.DISMTools.Stable' }
        @{ Type = 'app'; Category = 'Microsoft Tools'; Label = '.NET Desktop Runtime 8';   WingetId = 'Microsoft.DotNet.DesktopRuntime.8' }
        @{ Type = 'app'; Category = 'Microsoft Tools'; Label = '.NET Desktop Runtime 9';   WingetId = 'Microsoft.DotNet.DesktopRuntime.9' }
        @{ Type = 'app'; Category = 'Microsoft Tools'; Label = 'PowerToys';                WingetId = 'Microsoft.PowerToys' }
        @{ Type = 'app'; Category = 'Microsoft Tools'; Label = 'Visual C++ 2015-2022 x86'; WingetId = 'Microsoft.VCRedist.2015+.x86' }
        @{ Type = 'app'; Category = 'Microsoft Tools'; Label = 'Visual C++ 2015-2022 x64'; WingetId = 'Microsoft.VCRedist.2015+.x64' }
        # Documents & Office
        @{ Type = 'app'; Category = 'Documents & Office'; Label = 'Adobe Acrobat Reader'; WingetId = 'Adobe.Acrobat.Reader.64-bit' }
        @{ Type = 'app'; Category = 'Documents & Office'; Label = 'Foxit PDF Reader';     WingetId = 'Foxit.FoxitReader' }
        @{ Type = 'app'; Category = 'Documents & Office'; Label = 'PDF24 Creator';        WingetId = 'geeksoftware.PDF24Creator' }
        @{ Type = 'app'; Category = 'Documents & Office'; Label = 'LibreOffice';          WingetId = 'TheDocumentFoundation.LibreOffice' }
        @{ Type = 'app'; Category = 'Documents & Office'; Label = 'ONLYOFFICE';           WingetId = 'ONLYOFFICE.DesktopEditors' }
        # Multimedia
        @{ Type = 'app'; Category = 'Multimedia'; Label = 'OBS Studio';        WingetId = 'OBSProject.OBSStudio' }
        @{ Type = 'app'; Category = 'Multimedia'; Label = 'VLC Media Player';   WingetId = 'VideoLAN.VLC' }
        # Diagnostics & Pro Tools
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'Angry IP Scanner';           WingetId = 'angryziber.AngryIPScanner' }
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'Nmap';                       WingetId = 'Insecure.Nmap' }
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'GPU-Z';                      WingetId = 'TechPowerUp.GPU-Z' }
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'CPU-Z';                      WingetId = 'CPUID.CPU-Z' }
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'Display Driver Uninstaller'; WingetId = 'Wagnardsoft.DisplayDriverUninstaller' }
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'PuTTY';                      WingetId = 'PuTTY.PuTTY' }
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'Wireshark';                  WingetId = 'WiresharkFoundation.Wireshark' }
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'HWiNFO64';                   WingetId = 'REALiX.HWiNFO' }
        @{ Type = 'app'; Category = 'Diagnostics & Pro Tools'; Label = 'CrystalDiskInfo';            WingetId = 'CrystalDewWorld.CrystalDiskInfo' }
        # Utilities
        @{ Type = 'app'; Category = 'Utilities'; Label = '7-Zip';            WingetId = '7zip.7zip' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'Notepad++';        WingetId = 'Notepad++.Notepad++' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'Ventoy';           WingetId = 'Ventoy.Ventoy' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'LocalSend';        WingetId = 'LocalSend.LocalSend' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'AnyDesk';          WingetId = 'AnyDesk.AnyDesk' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'Google Drive';     WingetId = 'Google.GoogleDrive' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'KeePassXC';        WingetId = 'KeePassXCTeam.KeePassXC' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'MSI Afterburner';  WingetId = 'Guru3D.Afterburner' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'qBittorrent';      WingetId = 'qBittorrent.qBittorrent' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'Revo Uninstaller'; WingetId = 'RevoUninstaller.RevoUninstaller' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'WizTree';          WingetId = 'AntibodySoftware.WizTree' }
        @{ Type = 'app'; Category = 'Utilities'; Label = 'WinDirStat';       WingetId = 'WinDirStat.WinDirStat' }
    )
    Tweaks  = @(
        # --- Essential Tweaks (privacy / debloat / performance) ---
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable Activity History';
           Reg = @(
               @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed';     On = 0; Off = 1; Kind = 'DWord' }
               @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities';  On = 0; Off = 1; Kind = 'DWord' }
               @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities';   On = 0; Off = 1; Kind = 'DWord' }
           ) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable telemetry';
           Reg = @(
               @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; On = 0; Off = 1; Kind = 'DWord' }
               @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; On = 0; Off = 1; Kind = 'DWord' }
               @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackProgs'; On = 0; Off = 1; Kind = 'DWord' }
           );
           SvcOff = @('DiagTrack', 'dmwappushservice') }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable consumer features (suggested apps)';
           Reg = @(@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable GameDVR';
           Reg = @(
               @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; On = 0; Off = 1; Kind = 'DWord' }
               @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; On = 0; Off = 1; Kind = 'DWord' }
           ) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable location tracking';
           Reg = @(
               @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'; Name = 'Value'; On = 'Deny'; Off = 'Allow'; Kind = 'String' }
               @{ Path = 'HKLM:\SYSTEM\Maps'; Name = 'AutoUpdateEnabled'; On = 0; Off = 1; Kind = 'DWord' }
           ) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable Storage Sense';
           Reg = @(@{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'; Name = '01'; On = 0; Off = 1; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable background apps';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name = 'GlobalUserDisabled'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable Copilot';
           Reg = @(@{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable Notepad AI features';
           Reg = @(@{ Path = 'HKLM:\SOFTWARE\Policies\WindowsNotepad'; Name = 'DisableAIFeatures'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable Delivery Optimization';
           Reg = @(@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; On = 0; Off = 1; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Disable Teredo (IPv6 transition)';
           Reg = @(@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'; Name = 'DisabledComponents'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Essential Tweaks'; Label = 'Enable long paths (>260 chars)';
           Reg = @(@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'; Name = 'LongPathsEnabled'; On = 1; Off = 0; Kind = 'DWord' }) }

        # --- Preferences (UI / quality of life) ---
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Show file extensions';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; On = 0; Off = 1; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Show hidden files';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Hidden'; On = 1; Off = 2; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Dark theme (apps + system)';
           Reg = @(
               @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme';   On = 0; Off = 1; Kind = 'DWord' }
               @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; On = 0; Off = 1; Kind = 'DWord' }
           ) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Disable Bing/web search in Start menu';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; On = 0; Off = 1; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Disable taskbar Widgets';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarDa'; On = 0; Off = 1; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Disable lock screen tips/ads';
           Reg = @(
               @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'RotatingLockScreenOverlayEnabled'; On = 0; Off = 1; Kind = 'DWord' }
               @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338387Enabled';  On = 0; Off = 1; Kind = 'DWord' }
           ) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Align taskbar to the left';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAl'; On = 0; Off = 1; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Hide Task View button';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowTaskViewButton'; On = 0; Off = 1; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Hide taskbar Search box';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; On = 0; Off = 1; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Show seconds in taskbar clock';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSecondsInSystemClock'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'System tray battery percentage';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'IsBatteryPercentageEnabled'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'End Task on taskbar right-click (Win11)';
           Reg = @(@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Name = 'TaskbarEndTask'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'Verbose logon messages';
           Reg = @(@{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'VerboseStatus'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Preferences'; Label = 'NumLock on startup';
           Reg = @(@{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'InitialKeyboardIndicators'; On = '2'; Off = '0'; Kind = 'String' }) }

        # --- Advanced Tweaks (CAUTION) ---
        @{ Type = 'tweak'; Category = 'Advanced Tweaks (CAUTION)'; Label = 'Disable Hibernation';
           ApplyScript = 'powercfg /hibernate off'; UndoScript = 'powercfg /hibernate on' }
        @{ Type = 'tweak'; Category = 'Advanced Tweaks (CAUTION)'; Label = 'Set system clock to UTC (dual-boot)';
           Reg = @(@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'; Name = 'RealTimeIsUniversal'; On = 1; Off = 0; Kind = 'QWord' }) }
        @{ Type = 'tweak'; Category = 'Advanced Tweaks (CAUTION)'; Label = 'Disable Fullscreen Optimizations';
           Reg = @(@{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_DXGIHonorFSEWindowsCompatible'; On = 1; Off = 0; Kind = 'DWord' }) }
        @{ Type = 'tweak'; Category = 'Advanced Tweaks (CAUTION)'; Label = 'Disable Sticky Keys shortcut';
           Reg = @(@{ Path = 'HKCU:\Control Panel\Accessibility\StickyKeys'; Name = 'Flags'; On = '506'; Off = '58'; Kind = 'String' }) }
        @{ Type = 'tweak'; Category = 'Advanced Tweaks (CAUTION)'; Label = 'Detailed BSoD information';
           Reg = @(@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'; Name = 'DisplayParameters'; On = 1; Off = 0; Kind = 'DWord' }) }

        # --- Debloat (remove preinstalled apps; not reversible) ---
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'News + Weather';        Appx = @('Microsoft.BingNews', 'Microsoft.BingWeather') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Xbox apps';             Appx = @('Microsoft.GamingApp', 'Microsoft.XboxApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Solitaire Collection';  Appx = @('Microsoft.MicrosoftSolitaireCollection') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Mail and Calendar';     Appx = @('microsoft.windowscommunicationsapps') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Maps';                  Appx = @('Microsoft.WindowsMaps') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'People';                Appx = @('Microsoft.People') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Get Help + Tips';       Appx = @('Microsoft.GetHelp', 'Microsoft.Getstarted') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Office Hub + To Do';    Appx = @('Microsoft.MicrosoftOfficeHub', 'Microsoft.Todos') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Clipchamp';             Appx = @('Clipchamp.Clipchamp') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Feedback Hub';          Appx = @('Microsoft.WindowsFeedbackHub') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Teams (consumer)';      Appx = @('MicrosoftTeams', 'MSTeams') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Zune Music + Video';    Appx = @('Microsoft.ZuneMusic', 'Microsoft.ZuneVideo') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Power Automate';        Appx = @('Microsoft.PowerAutomateDesktop') }
        @{ Type = 'debloat'; Category = 'Debloat (remove bloatware)'; Label = 'Quick Assist';          Appx = @('MicrosoftCorporationII.QuickAssist') }
    )
    Config  = @(
        # Features (DISM optional features)
        @{ Type = 'feature'; Category = 'Features'; Label = '.NET Framework 3.5';        Feature = @('NetFx3') }
        @{ Type = 'feature'; Category = 'Features'; Label = 'Hyper-V';                    Feature = @('Microsoft-Hyper-V-All') }
        @{ Type = 'feature'; Category = 'Features'; Label = 'WSL (Linux subsystem)';      Feature = @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') }
        @{ Type = 'feature'; Category = 'Features'; Label = 'Windows Sandbox';            Feature = @('Containers-DisposableClientVM') }
        @{ Type = 'feature'; Category = 'Features'; Label = 'Telnet Client';              Feature = @('TelnetClient') }
        @{ Type = 'feature'; Category = 'Features'; Label = 'Legacy Media (DirectPlay)';  Feature = @('DirectPlay') }
        @{ Type = 'feature'; Category = 'Features'; Label = 'NFS Client';                 Feature = @('ServicesForNFS-ClientOnly', 'ClientForNFS-Infrastructure') }
        # Fixes
        @{ Type = 'fn'; Category = 'Fixes'; Label = 'Create System Restore Point';        Action = 'Invoke-WMRestorePoint' }
        @{ Type = 'fn'; Category = 'Fixes'; Label = 'System Corruption Scan (SFC + DISM)'; Action = 'Invoke-WMSfcDism' }
        @{ Type = 'fn'; Category = 'Fixes'; Label = 'Windows Update - Reset';              Action = 'Invoke-WMWUReset' }
        @{ Type = 'fn'; Category = 'Fixes'; Label = 'Network - Reset';                     Action = 'Invoke-WMNetworkReset' }
        @{ Type = 'fn'; Category = 'Fixes'; Label = 'WinGet - Reinstall / Repair';         Action = 'Invoke-WMWingetReinstall' }
        @{ Type = 'fn'; Category = 'Fixes'; Label = 'Time Sync (NTP) - Enable';            Action = 'Invoke-WMEnableNtp' }
        @{ Type = 'fn'; Category = 'Fixes'; Label = 'Restart Explorer';                    Action = 'Invoke-WMRestartExplorer' }
        @{ Type = 'fn'; Category = 'Fixes'; Label = 'Component Store Cleanup (slow)';      Action = 'Invoke-WMComponentCleanup' }
        # Legacy Windows Panels
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'Control Panel';        Action = 'Invoke-WMControlPanel' }
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'Network Connections';  Action = 'Invoke-WMNetworkPanel' }
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'Power Options';        Action = 'Invoke-WMPowerPanel' }
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'Sound Settings';       Action = 'Invoke-WMSoundPanel' }
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'System Properties';    Action = 'Invoke-WMSystemPanel' }
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'Device Manager';       Action = 'Invoke-WMDeviceManager' }
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'Computer Management';  Action = 'Invoke-WMComputerMgmt' }
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'Services';             Action = 'Invoke-WMServicesPanel' }
        @{ Type = 'fn'; Category = 'Legacy Panels'; Label = 'Devices and Printers'; Action = 'Invoke-WMPrintersPanel' }
        # Remote Access
        @{ Type = 'fn'; Category = 'Remote Access'; Label = 'OpenSSH Server - Enable'; Action = 'Invoke-WMEnableOpenSSH' }
        # Local accounts
        @{ Type = 'fn'; Category = 'Local Accounts'; Label = 'Create local admin (itadmin)'; Action = 'Invoke-WMCreateAdmin' }
        # DNS (applies to active physical adapters)
        @{ Type = 'fn'; Category = 'DNS'; Label = 'Cloudflare (1.1.1.1)'; Action = 'Invoke-WMDnsCloudflare' }
        @{ Type = 'fn'; Category = 'DNS'; Label = 'Google (8.8.8.8)';     Action = 'Invoke-WMDnsGoogle' }
        @{ Type = 'fn'; Category = 'DNS'; Label = 'Quad9 (9.9.9.9)';      Action = 'Invoke-WMDnsQuad9' }
        @{ Type = 'fn'; Category = 'DNS'; Label = 'Automatic (DHCP)';     Action = 'Invoke-WMDnsAuto' }
    )
    StandardMaintenance = @(
        @{ Category = 'Diagnostics'; Label = 'System Summary + Inventory CSV'; Action = 'Invoke-WMSystemSummary'; Default = $false }
        @{ Category = 'Diagnostics'; Label = 'Pending Reboot Check';           Action = 'Invoke-WMRebootCheck';   Default = $false }
        @{ Category = 'Diagnostics'; Label = 'Startup Items';                  Action = 'Invoke-WMStartupItems';  Default = $false }
        @{ Category = 'Diagnostics'; Label = 'Event Log (critical, 7 days)';   Action = 'Invoke-WMEventLog';      Default = $false }
        @{ Category = 'Updates'; Label = 'Windows Update';                  Action = 'Invoke-WMWindowsUpdate'; Default = $false }
        @{ Category = 'Updates'; Label = 'Microsoft Store (apps)';          Action = 'Invoke-WMStoreUpdate';   Default = $false }
        @{ Category = 'Updates'; Label = 'Microsoft Office (Click-to-Run)'; Action = 'Invoke-WMOfficeUpdate';  Default = $false }
        @{ Category = 'Updates'; Label = 'winget upgrade --all';            Action = 'Invoke-WMWingetUpgradeAll'; Default = $false }
        @{ Category = 'Updates'; Label = 'Lenovo Vantage';                   Action = 'Invoke-WMLenovoVantage';     Default = $false; OemMatch = 'Lenovo' }
        @{ Category = 'Updates'; Label = 'HP Support Assistant';             Action = 'Invoke-WMHPSupport';         Default = $false; OemMatch = 'HP|Hewlett' }
        @{ Category = 'Updates'; Label = 'Dell Command | Update';            Action = 'Invoke-WMDellCommandUpdate'; Default = $false; OemMatch = 'Dell' }
        @{ Category = 'Updates'; Label = 'Intel Driver & Support Assistant'; Action = 'Invoke-WMIntelDSA';          Default = $false }
        @{ Category = 'Cleanup'; Label = 'Clean temp + Disk Cleanup + Prefetch (C: only)'; Action = 'Invoke-WMCleanup'; Default = $false }
        @{ Category = 'Tools'; Control = 'button'; Type = 'openapp'; Label = 'Open CrystalDiskInfo';   WingetId = 'CrystalDewWorld.CrystalDiskInfo'; ExeMatch = '^DiskInfo(64|32)\.exe$' }
        @{ Category = 'Tools'; Control = 'button'; Type = 'openapp'; Label = 'Open HWiNFO64';          WingetId = 'REALiX.HWiNFO';                  ExeMatch = '^HWiNFO(64)?\.exe$' }
        @{ Category = 'Tools'; Control = 'button'; Type = 'openapp'; Label = 'Open CPU-Z';             WingetId = 'CPUID.CPU-Z';                    ExeMatch = '^cpuz(_x64)?\.exe$' }
        @{ Category = 'Tools'; Control = 'button'; Type = 'openapp'; Label = 'Open GPU-Z';             WingetId = 'TechPowerUp.GPU-Z';              ExeMatch = '^GPU-Z.*\.exe$' }
        @{ Category = 'Tools'; Control = 'button'; Type = 'openapp'; Label = 'Open Angry IP Scanner';  WingetId = 'angryziber.AngryIPScanner';      ExeMatch = '^(Angry IP Scanner|ipscan).*\.exe$' }
        @{ Category = 'Tools'; Control = 'button'; Type = 'fn'; Label = 'Open reports folder';  Action = 'Invoke-WMOpenReports' }
        # Windows Defender
        @{ Category = 'Windows Defender'; Control = 'button'; Type = 'fn'; Label = 'Quick scan'; Action = 'Invoke-WMDefenderQuick' }
        @{ Category = 'Windows Defender'; Control = 'button'; Type = 'fn'; Label = 'Full scan';  Action = 'Invoke-WMDefenderFull' }
    )
    Supremo = @(
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Acrilfer';   PwB64 = 'QWNyaWxmZXJAMjAyNSM=';     GroupId = 'vaCT6vk8NZzGhGySi' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'BAH';        PwB64 = 'QkFIVGVzdGUyMDI0';         GroupId = 'iZq5RXWqWnNRC5P4o' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Coperol';    PwB64 = 'Q29wZXJvbEAyMDI1Iw==';     GroupId = 'RKC8inKNZyzymP6QQ' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Domuscar';   PwB64 = 'JjFiPE5ZLlZhaXo8Vw==';     GroupId = 'nf5zibhLwCBvpr2vD' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Farol';      PwB64 = 'RmFyb2xAMjAyNSM=';         GroupId = 'S8or2YKeKbbkk6Zsm' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Feliciano';  PwB64 = 'RmVsaWNpYW5vQDIwMjUj';     GroupId = 'FcaGbNjgcBLY5Q7xZ' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Goldinix';   PwB64 = 'R29sZGlub3hAMjAyNSM=';     GroupId = 'nKjBHc4TyjFhhzmS7' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Grand Atlas';PwB64 = 'R3JhbmRhdGxhc0AyMDI1Iw=='; GroupId = 'RKC8inKNZyzymP6QQ' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Grupo LL';   PwB64 = 'R3J1cG9sbEAyMDI1Iw==';     GroupId = 'JQ3GXrBoFkDqEwzpW' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'HBP';        PwB64 = 'SGJwQDIwMjUj';             GroupId = 'gFJ5Pkczm8woHBviq' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'JVG';        PwB64 = 'SnZnQDIwMjUj';             GroupId = 'FMGBFcKQnNkwk9wZh' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'KF';         PwB64 = 'S2V0YUAyMDI1Iw==';         GroupId = 'ZcnoMMi8yGwPvQX2Y' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'LHC';        PwB64 = 'TGVnYWN5QDIwMjUj';         GroupId = 'Kaqzmeh62Lh3KdFpL' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Logimaris';  PwB64 = 'TG9nQDIwMjUjIQ==';         GroupId = '3KcTtZehxYe4mYSW8' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'MCB';        PwB64 = 'TWNiQDIwMjUj';             GroupId = 'YTX8ZBHr3yqgjqpS8' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'NBG';        PwB64 = 'TmV2YWRhQDIwMjUj';         GroupId = 'YAf6zw3p7L4HmMTvz' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'Pfruta';     PwB64 = 'UGZydXRhQDIwMjUj';         GroupId = 'YZdaaAAoNmmscSXHR' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'POS';        PwB64 = 'UG9zQDIwMjUj';             GroupId = 'TzonoanXdx3KwpaB3' }
        @{ Type = 'supremo'; Control = 'button'; Category = 'Supremo Clients'; Label = 'VDM';        PwB64 = 'VmRtQDIwMjUj';             GroupId = '3S5necYMFX6JqFLoX' }
    )
}

# Control type per category (WinUtil-style): preferences = immediate toggles,
# fixes/panels/remote = one-click buttons; everything else = batch checkbox.
foreach ($k in $Config.Keys) {
    foreach ($item in $Config[$k]) {
        if (-not $item.Control) {
            $item.Control = switch ($item.Category) {
                'Preferences'   { 'toggle' }
                'Fixes'         { 'button' }
                'Legacy Panels' { 'button' }
                'Remote Access' { 'button' }
                default         { 'check' }
            }
        }
        if (-not $item.Id) { $item.Id = "$k|$($item.Label)" }   # stable key for profiles
    }
}

# ============================================================
#  WPF UI  (dark theme, WinUtil-style)
# ============================================================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="CW Maintenance Utility" Height="720" Width="1180" WindowStartupLocation="CenterScreen"
        FontSize="14" Foreground="#CDD6F4" Background="#1E1E2E">
  <Window.Resources>
    <SolidColorBrush x:Key="Bg"     Color="#1E1E2E"/>
    <SolidColorBrush x:Key="Panel"  Color="#181825"/>
    <SolidColorBrush x:Key="Fg"     Color="#CDD6F4"/>
    <SolidColorBrush x:Key="Accent" Color="#89B4FA"/>
    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#CDD6F4"/>
      <Setter Property="Background" Value="#313244"/>
      <Setter Property="Padding" Value="14,6"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="Bd" Background="#313244" Margin="2,0" CornerRadius="4,4,0,0" Padding="14,6">
              <ContentPresenter x:Name="Cp" ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center" TextElement.Foreground="#CDD6F4"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#89B4FA"/>
                <Setter TargetName="Cp" Property="TextElement.Foreground" Value="#11111B"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#CDD6F4"/>
      <Setter Property="Margin" Value="6,5"/>
      <Setter Property="FontSize" Value="14"/>
    </Style>
    <Style TargetType="ToggleButton">
      <Setter Property="Foreground" Value="#CDD6F4"/>
      <Setter Property="Margin" Value="6,5"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToggleButton">
            <StackPanel x:Name="root" Orientation="Horizontal" Background="Transparent">
              <Border x:Name="track" Width="38" Height="20" CornerRadius="10" Background="#45475A" VerticalAlignment="Center">
                <Border x:Name="knob" Width="14" Height="14" CornerRadius="7" Background="#CDD6F4" HorizontalAlignment="Left" Margin="3,0,0,0"/>
              </Border>
              <ContentPresenter VerticalAlignment="Center" Margin="8,0,0,0"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="root" Property="Opacity" Value="0.9"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="track" Property="Background" Value="#89B4FA"/>
                <Setter TargetName="knob" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="knob" Property="Margin" Value="0,0,3,0"/>
                <Setter TargetName="knob" Property="Background" Value="#11111B"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#89B4FA"/>
      <Setter Property="Foreground" Value="#11111B"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="Margin" Value="4,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.85"/></Trigger>
              <Trigger Property="IsPressed"   Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.70"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#181825" Padding="16,10">
      <StackPanel Orientation="Horizontal">
        <TextBlock Text="CW Maintenance Utility" Foreground="#CDD6F4" FontSize="20" FontWeight="Bold"/>
      </StackPanel>
    </Border>

    <Border DockPanel.Dock="Bottom" Background="#181825">
      <Grid Margin="10,8">
        <TextBlock x:Name="StatusText" Text="Ready" Foreground="#A6ADC8" FontSize="12" VerticalAlignment="Center" HorizontalAlignment="Left" TextTrimming="CharacterEllipsis" MaxWidth="520"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="BtnImport"      Content="Import"      Background="#45475A" Foreground="#CDD6F4"/>
          <Button x:Name="BtnExport"      Content="Export"      Background="#45475A" Foreground="#CDD6F4"/>
          <Button x:Name="BtnRecommended" Content="Recommended" Background="#A6E3A1" Foreground="#11111B"/>
          <Button x:Name="BtnAll"         Content="Select all"  Background="#45475A" Foreground="#CDD6F4"/>
          <Button x:Name="BtnNone"        Content="Clear"       Background="#45475A" Foreground="#CDD6F4"/>
          <Button x:Name="BtnUndo"        Content="Undo tweaks" Background="#45475A" Foreground="#CDD6F4"/>
          <Button x:Name="BtnUninstall"   Content="Uninstall"   Background="#F38BA8" Foreground="#11111B"/>
          <Button x:Name="BtnRun"         Content="RUN"         Width="110"/>
        </StackPanel>
      </Grid>
    </Border>

    <TabControl x:Name="Tabs" Background="#1E1E2E" BorderThickness="0" Margin="8">
      <TabItem Header="Standard Maintenance"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="Panel_StandardMaintenance" Margin="10"/></ScrollViewer></TabItem>
      <TabItem Header="Install"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="Panel_Install" Margin="10"/></ScrollViewer></TabItem>
      <TabItem Header="Tweaks"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="Panel_Tweaks" Margin="10"/></ScrollViewer></TabItem>
      <TabItem Header="Config"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="Panel_Config" Margin="10"/></ScrollViewer></TabItem>
      <TabItem Header="Supremo"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="Panel_Supremo" Margin="10"/></ScrollViewer></TabItem>
    </TabControl>
  </DockPanel>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)

# Current on/off state of a registry-based tweak (for toggle initial position).
function Get-WMTweakState {
    param($T)
    $r = @($T.Reg)[0]
    if (-not $r) { return $false }
    try {
        $cur = (Get-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction Stop).$($r.Name)
        return ("$cur" -eq "$($r.On)")
    } catch { return $false }
}

# Build an informative tooltip from the item's own data (no hand-written prose).
function Get-WMTooltip {
    param($It)
    switch ($It.Type) {
        'tweak' {
            $p = @($It.Reg | ForEach-Object { "$($_.Path)\$($_.Name)  ->  on=$($_.On) / off=$($_.Off)" })
            if ($It.SvcOff) { $p += "Services disabled on apply: $($It.SvcOff -join ', ')" }
            if ($It.ApplyScript) { $p += "Script: $($It.ApplyScript)" }
            return ($p -join "`n")
        }
        'app'     { return "winget id: $($It.WingetId)$(if ($It.Source) { "  (source: $($It.Source))" })" }
        'openapp' { return "Opens (installs if missing) - winget id: $($It.WingetId)" }
        'debloat' { return "Removes: $($It.Appx -join ', ')" }
        'feature' { return "DISM feature(s): $($It.Feature -join ', ')" }
        'supremo' { return "Supremo unattended /deploy - group $($It.GroupId)" }
        default   { return $It.Desc }
    }
}

# Populate tabs from config; keep references to all checkboxes.
$AllChecks = New-Object System.Collections.ArrayList
foreach ($tab in $Config.Keys) {
    $panel = $window.FindName("Panel_$tab")
    if (-not $panel) { continue }
    if (-not $Config[$tab] -or $Config[$tab].Count -eq 0) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "Coming soon (next phase)."
        $tb.Foreground = '#A6ADC8'
        $tb.Margin = '6,8'
        $panel.Children.Add($tb) | Out-Null
        continue
    }
    if ($Config[$tab][0].Category) {
        # WinUtil-style: multi-column grid of category blocks.
        $wrap = New-Object System.Windows.Controls.WrapPanel
        $wrap.Orientation = 'Horizontal'
        $cats = [ordered]@{}
        foreach ($item in $Config[$tab]) {
            if ($item.OemMatch -and $WMManufacturer -notmatch $item.OemMatch) { continue }
            if (-not $cats.Contains($item.Category)) { $cats[$item.Category] = New-Object System.Collections.ArrayList }
            $cats[$item.Category].Add($item) | Out-Null
        }
        foreach ($cat in $cats.Keys) {
            $col = New-Object System.Windows.Controls.StackPanel
            $col.Width = 250; $col.Margin = '4,4,18,12'
            $hdr = New-Object System.Windows.Controls.TextBlock
            $hdr.Text = $cat; $hdr.FontWeight = 'Bold'; $hdr.FontSize = 14; $hdr.Foreground = '#89DCEB'; $hdr.Margin = '0,0,0,4'
            $col.Children.Add($hdr) | Out-Null
            foreach ($item in $cats[$cat]) {
                switch ($item.Control) {
                    'button' {
                        # One-click action (Fixes / Legacy Panels / Remote Access).
                        $b = New-Object System.Windows.Controls.Button
                        $b.Content = $item.Label; $b.Tag = $item; $b.Margin = '0,3'
                        $b.HorizontalAlignment = 'Stretch'; $b.HorizontalContentAlignment = 'Left'
                        $b.Background = '#45475A'; $b.Foreground = '#CDD6F4'
                        $b.ToolTip = Get-WMTooltip $item
                        $b.Add_Click({ Start-WMRunItems @($this.Tag) 'apply' $false })
                        $col.Children.Add($b) | Out-Null
                    }
                    'toggle' {
                        # Immediate enable/disable switch, reflecting current system state.
                        $tg = New-Object System.Windows.Controls.Primitives.ToggleButton
                        $tg.Content = $item.Label; $tg.Tag = $item
                        $tg.ToolTip = Get-WMTooltip $item
                        $tg.IsChecked = (Get-WMTweakState $item)
                        $tg.Add_Click({ $m = if ($this.IsChecked) { 'apply' } else { 'undo' }; Start-WMRunItems @($this.Tag) $m $true })
                        $col.Children.Add($tg) | Out-Null
                    }
                    default {
                        $cb = New-Object System.Windows.Controls.CheckBox
                        $cb.Content = $item.Label; $cb.IsChecked = [bool]$item.Default; $cb.Tag = $item
                        $cb.ToolTip = Get-WMTooltip $item
                        $col.Children.Add($cb) | Out-Null
                        $AllChecks.Add($cb) | Out-Null
                    }
                }
            }
            $wrap.Children.Add($col) | Out-Null
        }
        # Search box (Install / Tweaks / Config): filters any labelled control
        # (checkbox, toggle, button) and hides category columns with no matches.
        if ($tab -in 'Install', 'Tweaks', 'Config') {
            $search = New-Object System.Windows.Controls.TextBox
            $search.Margin = '4,0,4,10'; $search.Padding = '6,4'; $search.FontSize = 13
            $search.Background = '#313244'; $search.Foreground = '#CDD6F4'; $search.BorderThickness = 0
            $search.Tag = $wrap
            $search.Add_GotFocus({ if ($this.Text -eq 'Search...') { $this.Text = '' } })
            $search.Add_TextChanged({
                $q = $this.Text.Trim()
                if ($q -eq 'Search...') { $q = '' }
                foreach ($c in $this.Tag.Children) {
                    $any = $false
                    foreach ($ch in $c.Children) {
                        $props = $ch.GetType().GetProperty('Content')
                        if ($props) {
                            $vis = ($q -eq '' -or "$($ch.Content)" -like "*$q*")
                            $ch.Visibility = if ($vis) { 'Visible' } else { 'Collapsed' }
                            if ($vis) { $any = $true }
                        }
                    }
                    $c.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
                }
            })
            $search.Text = 'Search...'
            $panel.Children.Add($search) | Out-Null
        }
        $panel.Children.Add($wrap) | Out-Null
        continue
    }
    foreach ($item in $Config[$tab]) {
        if ($item.OemMatch -and $WMManufacturer -notmatch $item.OemMatch) { continue }
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content   = $item.Label
        $cb.IsChecked = [bool]$item.Default
        $cb.Tag       = $item
        $cb.ToolTip   = Get-WMTooltip $item
        $panel.Children.Add($cb) | Out-Null
        $AllChecks.Add($cb) | Out-Null
    }
}

$BtnRun = $window.FindName('BtnRun')
$BtnAll = $window.FindName('BtnAll')
$BtnNone = $window.FindName('BtnNone')
$BtnUndo = $window.FindName('BtnUndo')
$BtnExport = $window.FindName('BtnExport')
$BtnImport = $window.FindName('BtnImport')
$BtnRecommended = $window.FindName('BtnRecommended')
$BtnUninstall = $window.FindName('BtnUninstall')
$StatusText = $window.FindName('StatusText')

$BtnAll.Add_Click({ foreach ($c in $AllChecks) { $c.IsChecked = $true } })
$BtnNone.Add_Click({ foreach ($c in $AllChecks) { $c.IsChecked = $false } })

# Export / Import a selection profile (the checked checkbox items) as JSON.
$BtnExport.Add_Click({
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = 'JSON profile (*.json)|*.json'; $dlg.FileName = 'winmaint-profile.json'
    if ($dlg.ShowDialog()) {
        $ids = @($AllChecks | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag.Id })
        ($ids | ConvertTo-Json) | Set-Content -Path $dlg.FileName -Encoding UTF8
        Write-Host "Profile saved: $($dlg.FileName) ($($ids.Count) item(s))." -ForegroundColor Green
    }
})
$BtnImport.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'JSON profile (*.json)|*.json'
    if ($dlg.ShowDialog()) {
        try {
            $ids = @(Get-Content -Path $dlg.FileName -Raw | ConvertFrom-Json)
            $set = @{}; foreach ($i in $ids) { $set["$i"] = $true }
            foreach ($c in $AllChecks) { $c.IsChecked = [bool]$set["$($c.Tag.Id)"] }
            Write-Host "Profile loaded: $($dlg.FileName)." -ForegroundColor Green
        } catch { Write-Host "Could not load profile: $_" -ForegroundColor Red }
    }
})

# Curated "Recommended" maintenance run: the usual per-machine job, in order.
# Returns the exact StandardMaintenance config objects, honouring the OEM filter
# (only the OEM tool matching this machine's manufacturer survives).
function Get-WMRecommendedItems {
    $wanted = @(
        'Windows Update'
        'Microsoft Store (apps)'
        'Microsoft Office (Click-to-Run)'
        'winget upgrade --all'
        'Lenovo Vantage'
        'HP Support Assistant'
        'Dell Command | Update'
        'Intel Driver & Support Assistant'
        'Clean temp + Disk Cleanup + Prefetch (C: only)'
        'Open CrystalDiskInfo'
        'Quick scan'
    )
    $result = New-Object System.Collections.ArrayList
    foreach ($label in $wanted) {
        $item = $Config.StandardMaintenance | Where-Object { $_.Label -eq $label } | Select-Object -First 1
        if (-not $item) { continue }
        if ($item.OemMatch -and $WMManufacturer -notmatch $item.OemMatch) { continue }
        [void]$result.Add($item)
    }
    return $result.ToArray()
}

$BtnRecommended.Add_Click({ Start-WMRunItems (Get-WMRecommendedItems) 'apply' $true })
$BtnUninstall.Add_Click({
    $apps = @($AllChecks | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag } | Where-Object { $_.Type -eq 'app' })
    if (-not $apps.Count) { Write-Host "No apps selected to uninstall." -ForegroundColor Yellow; return }
    Start-WMRunItems $apps 'uninstall' $false
})

# Build the initial-session-state for the worker runspace: inject all engine functions.
$engineFns = Get-ChildItem Function:\ | Where-Object { $_.Name -match 'WM' }
$iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
foreach ($fn in $engineFns) {
    $iss.Commands.Add(
        (New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($fn.Name, $fn.Definition))
    )
}

# Completion watcher (UI thread): re-enables the RUN button when the worker finishes.
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$script:WMps = $null
$script:WMhandle = $null
$timer.Add_Tick({
    if ($sync.Status) { $StatusText.Text = $sync.Status }
    if ($script:WMhandle -and $script:WMhandle.IsCompleted) {
        try { $script:WMps.EndInvoke($script:WMhandle) } catch {}
        $script:WMps.Runspace.Dispose(); $script:WMps.Dispose()
        $script:WMps = $null; $script:WMhandle = $null
        $sync.Running = $false
        $BtnRun.Content = 'RUN'; $BtnRun.IsEnabled = $true; $BtnUndo.IsEnabled = $true
        $sync.Status = 'Done.'; $StatusText.Text = 'Done.'
        Write-Host "`r`n==== DONE ====`r`n" -ForegroundColor Green
    }
})
$timer.Start()

# Core runner: run the given items in the worker runspace. $Mode is 'apply' or
# 'undo'. $Restart restarts Explorer afterwards if any tweak ran (so UI tweaks
# show). Used by batch RUN/Undo and by immediate toggles/buttons.
function Start-WMRunItems {
    param([object[]]$Items, [string]$Mode, [bool]$Restart)
    if ($sync.Running) { return }
    if (-not $Items -or $Items.Count -eq 0) { Write-Host "Nothing selected." -ForegroundColor Yellow; return }

    # --- Confirmations for sensitive items (UI thread, before launching) -------
    if ($Mode -eq 'uninstall') {
        $apps = @($Items | Where-Object { $_.Type -eq 'app' })
        $r = [System.Windows.MessageBox]::Show("Uninstall $($apps.Count) app(s) via winget?", "Confirm Uninstall", 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    if ($Mode -eq 'apply') {
        $deb = @($Items | Where-Object { $_.Type -eq 'debloat' })
        if ($deb.Count) {
            $r = [System.Windows.MessageBox]::Show("Remove $($deb.Count) preinstalled app(s)? This cannot be undone.", "Confirm Debloat", 'YesNo', 'Warning')
            if ($r -ne 'Yes') { return }
        }
        if ($Items | Where-Object { $_.Action -eq 'Invoke-WMCreateAdmin' }) {
            try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue } catch {}
            $pw = [Microsoft.VisualBasic.Interaction]::InputBox("Password for the local admin 'itadmin':", "Create local admin", "itadmin")
            if (-not $pw) { return }
            $sync.AdminPw = $pw
        }
    }

    # Re-resolve winget each run so a repair/install during this session is picked
    # up without restarting the app.
    $script:Winget = Resolve-WMWinget
    Write-Host "WinMaint $WMVersion | winget: $(if ($script:Winget) { $script:Winget } else { 'not found' })" -ForegroundColor DarkGray

    $sync.Running = $true
    $BtnRun.Content = if ($Mode -eq 'undo') { 'Undoing...' } else { 'Running...' }
    $BtnRun.IsEnabled = $false; $BtnUndo.IsEnabled = $false

    $rs = [runspacefactory]::CreateRunspace($Host, $iss)
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync)
    $rs.SessionStateProxy.SetVariable('Winget', $Winget)

    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $ps.AddScript({
        param($items, $mode, $restart)
        try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
        # Invoke-WebRequest is dramatically slower in PS 5.1 while it renders a
        # progress bar; disabling it speeds downloads up by 10-50x.
        $ProgressPreference = 'SilentlyContinue'
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

        # Always ensure winget actually RUNS before installing apps. Checking the
        # path is not enough: it can resolve to something that exists but fails to
        # execute ("Access denied"). Test by invoking it; if it fails, (re)install.
        $wgWorks = $false
        if ($Winget) { try { & $Winget --version *> $null; $wgWorks = ($LASTEXITCODE -eq 0) } catch { $wgWorks = $false } }
        if ($mode -eq 'apply' -and (@($items | Where-Object { $_.Type -eq 'app' }).Count) -and -not $wgWorks) {
            Write-WMLog "winget not working; installing/repairing it before app installs..." step
            Invoke-WMWingetReinstall
            $global:Winget = Resolve-WMWinget
            $wgWorks = $false
            if ($Winget) { try { & $Winget --version *> $null; $wgWorks = ($LASTEXITCODE -eq 0) } catch {} }
            if ($wgWorks) { Write-WMLog "winget ready." ok } else { Write-WMLog "winget still unavailable; app installs may fail." warn }
        }

        $tweaked = $false; $done = 0; $failed = 0
        foreach ($it in $items) {
            try {
                if ($mode -eq 'uninstall')       { if ($it.Type -eq 'app') { Invoke-WMUninstallApp $it } }
                elseif ($it.Type -eq 'tweak')    { $tweaked = $true; Invoke-WMTweak $it $mode }
                elseif ($it.Type -eq 'feature')  { Invoke-WMFeature $it $mode }
                elseif ($mode -eq 'apply') {
                    if ($it.Type -eq 'app')         { Install-WMApp $it }
                    elseif ($it.Type -eq 'debloat') { Invoke-WMDebloat $it }
                    elseif ($it.Type -eq 'openapp') { Invoke-WMOpenApp $it }
                    elseif ($it.Type -eq 'supremo') { Invoke-WMSupremoDeploy $it }
                    else { & $it.Action }
                } else { continue }
                $done++
            } catch { $failed++; Write-WMLog "Error in $($it.Label): $_" err }
        }
        if ($tweaked) {
            Write-WMLog "Some changes need an Explorer restart or sign-out to show. Use Config > Fixes > 'Restart Explorer' when ready." warn
        }
        $lvl = if ($failed) { 'warn' } else { 'ok' }
        Write-WMLog "Summary: $done item(s) processed, $failed error(s)." $lvl
    }).AddArgument($Items).AddArgument($Mode).AddArgument($Restart) | Out-Null

    $script:WMps = $ps
    $script:WMhandle = $ps.BeginInvoke()
}

# Batch RUN / Undo: act on checked checkboxes only (toggles/buttons act immediately).
function Start-WMRun {
    param([string]$Mode)
    $selected = @($AllChecks | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
    Start-WMRunItems $selected $Mode $true
}

$BtnRun.Add_Click({ Start-WMRun 'apply' })
$BtnUndo.Add_Click({ Start-WMRun 'undo' })

if ($SelfTest) {
    Write-Host "SelfTest OK: XAML loaded, $($AllChecks.Count) checkbox(es) generated, $($engineFns.Count) engine functions."
    return
}

$window.ShowDialog() | Out-Null
