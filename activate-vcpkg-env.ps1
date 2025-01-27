Param(
    [Parameter(Mandatory = $false)]
    [String]
    $Prompt = "vcpkg",
    [String]
    $HostTriplet = "x64-win-llvm",
    [String]
    $Triplet = $HostTriplet,
    [String]
    $ManifestDir = "./vcpkg",
    [String]
    $VcpkgRootDir = (Join-Path -Path $PSScriptRoot -ChildPath "vcpkg"),
    [String]
    $ManifestFeatures = @()

)

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

function script:configure_toolchain {
    # Define placeholders and their values
    $placeholders = @{
        "@VCPKG_INSTALLED_DIR@"   = "MyProject"
        "@VCPKG_TARGET_TRIPLET@" = "$Triplet"
        "@VCPKG_HOST_TRIPLET@" = "$HostTriplet"
        "@VCPKG_CHAINLOAD_TOOLCHAIN_FILE@" = "1.0.0"
    }

    # Load the template file
    $template = Get-Content -Path "config.template" -Raw

    # Replace placeholders with actual values
    foreach ($placeholder in $placeholders.Keys) {
        $template = $template -replace [regex]::Escape($placeholder), $placeholders[$placeholder]
    }

    # Write the configured file
    $template | Set-Content -Path "config.h"

    Write-Host "Configuration file generated: config.h"
}

deactivate -nondestructive

. ./env-cleanup.ps1

if (-not $Env:VCPKG_ENV_DISABLE_PROMPT) {
    Write-Verbose "Setting prompt to '$Prompt'"

    function global:_OLD_PROMPT_NAME { "" }
    Copy-Item -Path function:prompt -Destination function:_OLD_PROMPT_NAME
    New-Variable -Name _VCPKG_PROMPT_PREFIX -Description "vcpkg environment prompt prefix" -Scope Global -Option ReadOnly -Visibility Public -Value $Prompt

    function global:prompt {
        Write-Host -NoNewline -ForegroundColor Green "($_VCPKG_PROMPT_PREFIX) "
        _OLD_PROMPT_NAME
    }
    $env:VCPKG_ENV_PROMPT = $Prompt
}

Copy-Item -Path Env:PATH -Destination Env:_OLD_PATH


if (-not (Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "vcpkg/vcpkg.exe"))) {
  Invoke-WebRequest -Uri https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/vcpkg-init/vcpkg-init.ps1 `
                    -OutFile (Join-Path -Path $PSScriptRoot -ChildPath "vcpkg/vcpkg-init.ps1")

  New-Item -Path ".\vcpkg\.vcpkg-root" -ItemType File -Force
}

. .\vcpkg\vcpkg-init.ps1

$Env:VCPKG_FORCE_DOWNLOADED_BINARIES = 1

if (-not $env:VCPKG_DOWNLOADS) {
    $env:VCPKG_DOWNLOADS = Join-Path -Path $PSScriptRoot -ChildPath "vcpkg/downloads"
    $res = New-Item -Path $Env:VCPKG_DOWNLOADS -ItemType "directory" -Force
}

if (-not $env:VCPKG_DEFAULT_BINARY_CACHE) {
    $env:VCPKG_DEFAULT_BINARY_CACHE = Join-Path -Path $PSScriptRoot -ChildPath "vcpkg/cache"
    $res = New-Item -Path $Env:VCPKG_DEFAULT_BINARY_CACHE -ItemType "directory" -Force
}

$Env:X_VCPKG_REGISTRIES_CACHE = (Join-Path -Path $PSScriptRoot -ChildPath "vcpkg/registries") # Needs to be set for 'vcpkg fetch' for some reason
$res = New-Item -Path $Env:X_VCPKG_REGISTRIES_CACHE -ItemType "directory" -Force

$vcpkg_exe = ".\vcpkg\vcpkg.exe"
$paths = @{}
$tools = @("cmake", "ninja", "git")
foreach ($tool in $tools) {
    $script:toolPath = & $vcpkg_exe fetch $tool
    $paths[$tool] = Split-Path ($toolPath.Trim())
    $env:PATH = "$($env:PATH);$($paths[$tool])"
}
$vcpkg_root=$VcpkgRootDir
$vcpkg_installed="./bld/vcpkg"
$vcpkg_overlay_ports="./vcpkg/overlay-ports"
$vcpkg_overlay_triplets="./vcpkg/overlay-triplets"

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
  "--overlay-triplets=$vcpkg_overlay_triplets" | Write-Host
#            COMMAND "${Z_VCPKG_EXECUTABLE}" install
#                --triplet "${VCPKG_TARGET_TRIPLET}"
#                --vcpkg-root "${Z_VCPKG_ROOT_DIR}"
#                "--x-wait-for-lock"
#                "--x-manifest-root=${VCPKG_MANIFEST_DIR}"
#                "--x-install-root=${_VCPKG_INSTALLED_DIR}"
#                ${Z_VCPKG_FEATURE_FLAGS}
#                ${Z_VCPKG_ADDITIONAL_MANIFEST_PARAMS}
#                ${VCPKG_INSTALL_OPTIONS}

Write-Host "Setting up environment ..."
. ./$vcpkg_installed/$vcpkg_host_triplet/env-setup/llvm-env.ps1


#Write-Host $manifest_install