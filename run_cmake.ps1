Param(
    [String]
    $BuildDir = (Join-Path -Path $PSScriptRoot -ChildPath "bld"),
    [String]
    $CMakeToolchain = (Join-Path -Path $BuildDir -ChildPath "vcpkg_installed/x64-win-llvm/vcpkg.toolchain.loader.cmake")
)

& cmake "-G" "Ninja" "-S" "." "-B" "$BuildDir" `
  "-DCMAKE_TOOLCHAIN_FILE=$CMakeToolchain" "--fresh"  | Write-Host
