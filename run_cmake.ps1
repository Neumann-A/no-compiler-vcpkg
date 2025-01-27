& cmake "-G" "Ninja" "-S" "." "-B" "bld/x64-win-llvm" `
  "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$PSScriptROOT/vcpkg/overlay-triplets/x64-win-llvm/x64-win-llvm-toolchain.cmake" `
  "-DCMAKE_TOOLCHAIN_FILE=./vcpkg/scripts/buildsystems/vcpkg.cmake" `
  "-DVCPKG_TARGET_TRIPLET=x64-win-llvm" `
  "-DVCPKG_HOST_TRIPLET=x64-win-llvm" `
  "-DVCPKG_MANIFEST_DIR=./vcpkg" `
  "-DVCPKG_INSTALLED_DIR=./bld/vcpkg" `
  "-DVCPKG_OVERLAY_PORTS=./vcpkg/overlay-ports" `
  "-DVCPKG_OVERLAY_TRIPLETS=./vcpkg/overlay-triplets" | Write-Host
