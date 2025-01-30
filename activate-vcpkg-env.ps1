Param(
    [Parameter(Mandatory = $false)]
    [String]
    $Prompt = "vcpkg",
    [String]
    $HostTriplet = "x64-win-llvm",
    [String]
    $Triplet = $HostTriplet,
    [String]
    $ManifestDir = (Join-Path -Path $PSScriptRoot -ChildPath "vcpkg"),
    [String]
    $VcpkgRootDir = (Join-Path -Path $PSScriptRoot -ChildPath "vcpkg"),
    [String]
    $BuildDir = (Join-Path -Path $PSScriptRoot -ChildPath "bld"),
    [String]
    $VcpkgInstalledDir = (Join-Path -Path $BuildDir -ChildPath "vcpkg_installed"),
    [Array]
    $ManifestFeatures = @()
)

$vcpkg_root=$VcpkgRootDir
$vcpkg_installed=$VcpkgInstalledDir
$vcpkg_overlay_ports="$ManifestDir/overlay-ports"
$vcpkg_overlay_triplets="$ManifestDir/overlay-triplets"


function global:deactivate ([switch]$NonDestructive) {
    # Revert to original values

    # The prior prompt:
    if (Test-Path -Path Function:_OLD_PROMPT_NAME) {
        Copy-Item -Path Function:_OLD_PROMPT_NAME -Destination Function:prompt
        Remove-Item -Path Function:_OLD_PROMPT_NAME
    }

    # The prior PATH:
    if (Test-Path -Path Env:_OLD_PATH) {
        Copy-Item -Path Env:_OLD_PATH -Destination Env:PATH
        Remove-Item -Path Env:_OLD_PATH
    }

    # Just remove the _PYTHON_VENV_PROMPT_PREFIX altogether:
    if (Get-Variable -Name "_VCPKG_PROMPT_PREFIX" -ErrorAction SilentlyContinue) {
        Remove-Variable -Name _VCPKG_PROMPT_PREFIX -Scope Global -Force
    }

    if (Get-Variable -Name "VCPKG_FORCE_DOWNLOADED_BINARIES" -ErrorAction SilentlyContinue) {
        Remove-Variable -Name VCPKG_FORCE_DOWNLOADED_BINARIES -Scope Global -Force
    }

    if (Test-Path -Path function:cleanup_environment) {
      restore_environment
      Remove-Item -Path function:cleanup_environment
      Remove-Item -Path function:restore_environment
    }

    # Leave deactivate function in the global namespace if requested:
    if (-not $NonDestructive) {
        Remove-Item -Path function:deactivate
    }
}

function script:create_toolchain_loader() {
    # Define placeholders and their values
    $placeholders = @{
        "@VCPKG_INSTALLED_DIR@"   = $VcpkgInstalledDir -replace '\\', '/'
        "@VCPKG_TARGET_TRIPLET@" = "$Triplet"
        "@VCPKG_HOST_TRIPLET@" = "$HostTriplet"
        "@VCPKG_CHAINLOAD_TOOLCHAIN_FILE@" = "$vcpkg_overlay_triplets/$Triplet/$Triplet-toolchain.cmake" -replace '\\', '/'
    }

    # Load the template file
    $template = Get-Content -Path "vcpkg.toolchain.loader.template.cmake" -Raw

    # Replace placeholders with actual values
    foreach ($placeholder in $placeholders.Keys) {
        $template = $template -replace [regex]::Escape($placeholder), $placeholders[$placeholder]
    }

    # Write the configured file
    $template | Set-Content -Path "$vcpkg_installed/vcpkg.$Triplet-toolchain.loader.cmake"

    return "$vcpkg_installed/vcpkg.$Triplet-toolchain.loader.cmake"
}

deactivate -nondestructive

. ./env-cleanup.ps1

if (-not $Env:VCPKG_ENV_DISABLE_PROMPT) {
    Write-Verbose "Setting prompt to '$Prompt'"

    function global:_OLD_PROMPT_NAME { "" }
    Copy-Item -Path function:prompt -Destination function:_OLD_PROMPT_NAME
    New-Variable -Name _VCPKG_PROMPT_PREFIX -Description "vcpkg environment prompt prefix" -Scope Global -Option ReadOnly -Visibility Public -Value "$Prompt - Host:$HostTriplet - Target:$Triplet"

    function global:prompt {
        Write-Host -NoNewline -ForegroundColor Green "($_VCPKG_PROMPT_PREFIX) "
        _OLD_PROMPT_NAME
    }
    $env:VCPKG_ENV_PROMPT = $Prompt
}

Copy-Item -Path Env:PATH -Destination Env:_OLD_PATH

$vcpkg_exe = (Join-Path -Path $VcpkgRootDir -ChildPath "vcpkg.exe")
if (-not (Test-Path -Path $vcpkg_exe)) {
  Invoke-WebRequest -Uri https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/vcpkg-init/vcpkg-init.ps1 `
                    -OutFile "$VcpkgRootDir/vcpkg-init.ps1"

  New-Item -Path "$VcpkgRootDir\.vcpkg-root" -ItemType File -Force
}

. $VcpkgRootDir\vcpkg-init.ps1

$Env:VCPKG_FORCE_DOWNLOADED_BINARIES = 1

if (-not $env:VCPKG_DOWNLOADS) {
    $env:VCPKG_DOWNLOADS = Join-Path -Path $VcpkgRootDir -ChildPath "downloads"
    $res = New-Item -Path $Env:VCPKG_DOWNLOADS -ItemType "directory" -Force
}

if (-not $env:VCPKG_DEFAULT_BINARY_CACHE) {
    $env:VCPKG_DEFAULT_BINARY_CACHE = Join-Path -Path $VcpkgRootDir -ChildPath "cache"
    $res = New-Item -Path $Env:VCPKG_DEFAULT_BINARY_CACHE -ItemType "directory" -Force
}

$Env:X_VCPKG_REGISTRIES_CACHE = (Join-Path -Path $VcpkgRootDir -ChildPath "registries") # Needs to be set for 'vcpkg fetch' for some reason
$res = New-Item -Path $Env:X_VCPKG_REGISTRIES_CACHE -ItemType "directory" -Force


$paths = @{}
$tools = @("cmake", "ninja", "git")
foreach ($tool in $tools) {
    $script:toolPath = & $vcpkg_exe fetch $tool
    $paths[$tool] = Split-Path ($toolPath.Trim())
    $env:PATH = "$($env:PATH);$($paths[$tool])"
}

$env:VCPKG_DEFAULT_TRIPLET=$Triplet
$env:VCPKG_DEFAULT_HOST_TRIPLET=$HostTriplet

Write-Host "Running vcpkg install..."

& $vcpkg_exe install `
  "--triplet" "$Triplet" `
  "--host-triplet" "$HostTriplet" `
  "--vcpkg-root" "$VcpkgRootDir" `
  "--x-wait-for-lock" `
  "--x-manifest-root=$vcpkg_root" `
  "--x-install-root=$vcpkg_installed" `
  "--x-no-default-features" `
  "--feature-flags=$manifest_features" `
  "--overlay-ports=$vcpkg_overlay_ports" `
  "--overlay-triplets=$vcpkg_overlay_triplets" `
  "--no-print-usage" | Write-Host

Write-Host "Setting up environment ..."
. $vcpkg_overlay_triplets/$Triplet.env.ps1 -VcpkgInstalledDir $vcpkg_installed

$cmake_toolchain = create_toolchain_loader 

#Write-Host "CMake Toolchain generated at: $cmake_toolchain"
#Write-Output $cmake_toolchain
$env:CMAKE_TOOLCHAIN_FILE = $cmake_toolchain
#Write-Host $manifest_install