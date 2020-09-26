# Download the CLI install script to Agent.TempDirectory

# Write-Host "Installing dotnet CLI into $Env:AGENT_TEMPDIRECTORY folder for building"

[CmdletBinding(SupportsShouldProcess = $True)]
Param (
    [string]$SDKVersionForBuild
)

Function Test-Command([string]$command) {
    try {
        Get-Command $command -ErrorAction 'Stop' | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

$CLIRoot = Join-Path $Env:AGENT_TEMPDIRECTORY 'dotnet'
$DotNetInstall = Join-Path $CLIRoot 'dotnet-install.ps1'

# If 'dotnet-install.ps1' under dotnet folder doesn't exist, create dotnet folder and download dotnet-install.ps1 into dotnet folder.
if (-not (Test-Path $DotNetInstall)) {
    Write-Host "Downloading .NET SDK Install Script"
    New-Item -ItemType Directory -Force -Path $CLIRoot | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile $DotNetInstall
}

# Get version from SDKVersionForBuild, if only branch name specified, use the latest version for this branch
$CliChannel = $SDKVersionForBuild.Trim() -split ":"

$Channel = $CliChannel[0].Trim()
if ($CliChannel.Count -eq 1) {
    $Version = 'latest'
}
else {
    $Version = $CliChannel[1].Trim()
}

Write-Host "Channel: $Channel       Version: $Version" -ForegroundColor Cyan

if ($Version -eq 'latest') {
    # Get the latest specific version number for a certain channel from url like : https://dotnetcli.blob.core.windows.net/dotnet/Sdk/release/3.1.1xx/latest.version"
    $httpGetUrl = "https://dotnetcli.blob.core.windows.net/dotnet/Sdk/$Channel/latest.version"
    $versionFile = Invoke-RestMethod -Method Get -Uri $httpGetUrl

    $reader = [System.IO.StringReader]::new($versionFile)
    [int]$count = 0
    while ($line = $reader.ReadLine()) {
        if ($count -eq 1) {
            $SpecificVersion = $line.Trim()
        }
        $count += 1
    }
}
else {
    $SpecificVersion = $Version
}

Write-Host "The version of SDK should be installed is : $SpecificVersion" -ForegroundColor Cyan
$SdkPath = Join-Path $CLIRoot "sdk\$SpecificVersion"
Write-Host "Probing folder : $SdkPath" -ForegroundColor Cyan

# If folder with specific version doesn't exist, the download command will run
if (-not (Test-Path $SdkPath)) {
    # Install the latest .NET SDK from the specified channel/version
    Write-Host "$DotNetInstall $Channel $Version"
    & $DotNetInstall -i $CLIRoot -Channel $Channel -Version $Version
}

if (-not (Test-Path $SdkPath)) {
    Write-Error "Unable to find specific version of sdk. The CLI install may have failed."
}

# Display PATH env variable
$Env:PATH

if (-not (Test-Command dotnet)) {
    Write-Error "Unable to resolve dotnet.exe from the env:PATH. The CLI install may have failed."
}

# Display build info
& dotnet --info
