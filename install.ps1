# KlondikeCLI installer for Windows.
#
#   irm https://evilchuck666.github.io/KlondikeCLI/install.ps1 | iex
#
# Downloads the latest Windows release, checks it against SHA256SUMS.txt,
# installs KlondikeCLI.exe in %LOCALAPPDATA%\Programs\KlondikeCLI, adds that
# folder to your user PATH and creates Start menu and desktop shortcuts.
# No administrator rights are needed. Works with Windows PowerShell 5.1 and
# PowerShell 7.
#
# Everything runs inside a script block so that, when piped into iex, the
# settings below do not leak into your session, and errors never close the
# window (the script throws instead of calling exit).

& {
    $ErrorActionPreference = 'Stop'
    # Invoke-WebRequest is far slower in Windows PowerShell with a progress bar.
    $ProgressPreference = 'SilentlyContinue'

    $Repo = 'Evilchuck666/KlondikeCLI'
    $ReleaseUrl = "https://github.com/$Repo/releases/latest/download"
    $PackageName = 'KlondikeCLI-windows-x64.zip'
    # Only set on Windows; Assert-Supported stops anywhere else before it is used.
    $InstallDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs\KlondikeCLI' } else { $null }

    function Write-Step([string]$Message) {
        Write-Host "==> $Message" -ForegroundColor Cyan
    }

    function Assert-Supported {
        if ($env:OS -ne 'Windows_NT') {
            throw 'install.ps1 is for Windows. On GNU/Linux and macOS, use install.sh (see the README).'
        }
        $arch = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITEW6432')
        if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
        switch ($arch) {
            'AMD64' { }
            'ARM64' { Write-Warning 'There is no ARM64 build yet; installing the x64 build, which Windows runs through emulation.' }
            default { throw "KlondikeCLI needs 64-bit Windows (this system reports $arch)." }
        }
    }

    function Enable-Tls12 {
        # Windows PowerShell 5.1 may default to TLS 1.0, which GitHub rejects.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    function Get-ReleaseFile([string]$Name, [string]$Directory) {
        $url = "$ReleaseUrl/$Name"
        $path = Join-Path $Directory $Name
        try {
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
        } catch {
            throw "Could not download ${url}: $($_.Exception.Message)"
        }
        return $path
    }

    function Assert-Checksum([string]$File, [string]$SumsFile) {
        $name = Split-Path $File -Leaf
        $expected = $null
        foreach ($line in Get-Content -LiteralPath $SumsFile) {
            $parts = $line.Trim() -split '\s+', 2
            if ($parts.Count -eq 2 -and $parts[1].TrimStart('*') -eq $name) {
                $expected = $parts[0].ToLowerInvariant()
            }
        }
        if (-not $expected) { throw "$name is not listed in SHA256SUMS.txt." }
        $actual = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) { throw "Checksum mismatch for $name (expected $expected, got $actual)." }
        Write-Step 'Checksum verified.'
    }

    function Install-Executable([string]$Archive, [string]$WorkDir) {
        $extractDir = Join-Path $WorkDir 'extract'
        Expand-Archive -LiteralPath $Archive -DestinationPath $extractDir -Force
        $source = Join-Path $extractDir 'KlondikeCLI-windows-x64\KlondikeCLI.exe'
        if (-not (Test-Path -LiteralPath $source)) { throw 'KlondikeCLI.exe was not found in the downloaded package.' }

        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        $target = Join-Path $InstallDir 'KlondikeCLI.exe'
        try {
            Copy-Item -LiteralPath $source -Destination $target -Force
        } catch {
            throw "Could not write $target. If KlondikeCLI is running, close it and run the installer again. ($($_.Exception.Message))"
        }
        Write-Step "Installed $target"
        return $target
    }

    # Adds $Directory to the user PATH in the registry, keeping its value type
    # (REG_EXPAND_SZ) and any %VARIABLES% it holds unexpanded.
    function Add-ToUserPath([string]$Directory) {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        try {
            $current = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $entries = @($current -split ';' | Where-Object { $_ })
            foreach ($entry in $entries) {
                if ([Environment]::ExpandEnvironmentVariables($entry).TrimEnd('\') -ieq $Directory.TrimEnd('\')) {
                    return $false
                }
            }
            $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
            if ($current) { $kind = $key.GetValueKind('Path') }
            $key.SetValue('Path', (($entries + $Directory) -join ';'), $kind)
        } finally {
            $key.Close()
        }
        # Setting a variable through .NET tells Explorer and new terminals that
        # the environment changed; the dummy variable is removed straight away.
        [Environment]::SetEnvironmentVariable('KLONDIKECLI_INSTALLER', '1', 'User')
        [Environment]::SetEnvironmentVariable('KLONDIKECLI_INSTALLER', $null, 'User')
        $env:Path = "$env:Path;$Directory"
        return $true
    }

    # The shortcut runs the game through cmd so the window stays open at the
    # end ("Press any key to continue") to show the final result.
    function New-Shortcut([string]$Path, [string]$Exe) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($Path)
        $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\cmd.exe'
        $shortcut.Arguments = "/c `"title KlondikeCLI & `"$Exe`" & pause`""
        $shortcut.WorkingDirectory = Split-Path $Exe
        $shortcut.IconLocation = "$Exe,0"
        $shortcut.Description = 'Klondike solitaire in your terminal'
        $shortcut.Save()
    }

    function Install-KlondikeCLI {
        Assert-Supported
        Enable-Tls12

        $work = Join-Path ([IO.Path]::GetTempPath()) ('klondikecli-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        try {
            Write-Step "Downloading $PackageName from the latest release..."
            $archive = Get-ReleaseFile $PackageName $work
            $sums = Get-ReleaseFile 'SHA256SUMS.txt' $work
            Assert-Checksum $archive $sums
            $exe = Install-Executable $archive $work
        } finally {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }

        if (Add-ToUserPath $InstallDir) {
            Write-Step "Added $InstallDir to your PATH."
        }

        $startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'KlondikeCLI.lnk'
        $desktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'KlondikeCLI.lnk'
        New-Shortcut $startMenu $exe
        New-Shortcut $desktop $exe
        Write-Step 'Created shortcuts in the Start menu and on the desktop.'

        Write-Host ''
        Write-Step 'KlondikeCLI is installed.'
        Write-Host '    Open it from the Start menu or the desktop shortcut, or run KlondikeCLI in a new terminal.'
        Write-Host '    To uninstall, delete these and remove the folder from your user PATH:'
        Write-Host "      $InstallDir"
        Write-Host "      $startMenu"
        Write-Host "      $desktop"
    }

    try {
        Install-KlondikeCLI
    } catch {
        Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
