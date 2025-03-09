$tempPath = "C:\Program Files\GoBobDev\XTweaker\Temp"
$filename = Join-Path -Path $tempPath -ChildPath "XTweakerSetup.exe"
$url = "https://github.com/GoBobDev/XTweaker/releases/latest/download/XTweakerSetup.exe"
$urlJava = "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=249831_89d678f2be164786b292527658ca1605" # Latest Java link
$filenameJava = Join-Path -Path $tempPath -ChildPath "JavaRuntimeSetup.exe"

function Write-Log {
    param (
        [string]$message
    )
    Write-Host "[INFO] $message"
}

function Add-DefenderExclusion {
    param (
        [string]$path
    )
    try {
        Start-Process -FilePath "powershell" -ArgumentList "-Command `"Add-MpPreference -ExclusionPath '$path'`"" -Verb RunAs -Wait
    } catch {
        Write-Log "File ExclusionPath Add (MS Defender) failed: $_"
        exit 1
    }
}

function Remove-DefenderExclusion {
    param (
        [string]$path
    )
    try {
        Start-Process -FilePath "powershell" -ArgumentList "-Command `"Remove-MpPreference -ExclusionPath '$path'`"" -Verb RunAs -Wait
    } catch {
        Write-Log "File ExclusionPath Removing (MS Defender) failed: $_"
    }
}

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    return $principal.IsInRole($adminRole)
}

function Is-JavaInstalled {
    try {
        # Check if Java is in the PATH
        Get-Command java -ErrorAction Stop
        return $true
    } catch {
        Write-Log "Java not found in PATH. Checking registry..."
        # Check registry for Java installation
        $javaRegistryPath = "HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment"
        if (Test-Path $javaRegistryPath) {
            return $true
        } else {
            return $false
        }
    }
}

if (-not (Test-Admin)) {
    Write-Log "You need to run PowerShell as Administrator!"
    Write-Log "Press any key to exit."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

try {
    # Create directory if it doesn't exist
    if (-not (Test-Path -Path $tempPath)) {
        New-Item -Path $tempPath -ItemType Directory
    }

    Add-DefenderExclusion -path $filename

    Write-Log "Downloading XTweaker..."
    Invoke-WebRequest -Uri $url -OutFile $filename -ErrorAction Stop

    Write-Log "Searching if Java installed..."
    if (-not (Is-JavaInstalled)) {
        Write-Log "Java not installed. Downloading Java Runtime..."
        Invoke-WebRequest -Uri $urlJava -OutFile $filenameJava -ErrorAction Stop

        Write-Log "Installing Java Runtime..."
        # Use the silent flag for installation
        Start-Process -FilePath $filenameJava -ArgumentList '/s' -Verb RunAs -Wait

        # Clean up Java installer
        $removeCommandJava = "Remove-Item -Path '$filenameJava' -ErrorAction Stop"
        Start-Process -FilePath "powershell" -ArgumentList "-Command $removeCommandJava" -Verb RunAs -Wait
    } else {
        Write-Log "Java is already installed."
    }

    # Install XTweaker silently
    Start-Process -FilePath $filename -ArgumentList '/VERYSILENT /TASKS="desktopicon"' -Verb RunAs -Wait

    # Clean up XTweaker installer
    $removeCommandXTweaker = "Remove-Item -Path '$filename' -ErrorAction Stop"
    Start-Process -FilePath "powershell" -ArgumentList "-Command $removeCommandXTweaker" -Verb RunAs -Wait

    Remove-DefenderExclusion -path $filename

    Write-Log "Installation completed. Press any key to exit."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

} catch {
    Write-Log "Error occurred: $_"
    Write-Log "Press any key to exit."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
