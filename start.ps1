
Invoke-WebRequest -Uri https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/vcpkg-init/vcpkg-init.ps1 `
                  -OutFile vcpkg/vcpkg-init.ps1

New-Item -Path ".\vcpkg\.vcpkg-root" -ItemType File -Force
. .\vcpkg\vcpkg-init.ps1

$cmake = .\vcpkg\vcpkg.exe fetch cmake

& $cmake -G "Ninja" -S . -B bld `
    "-DCMAKE_TOOLCHAIN_FILE=vcpkg/scripts/buildsystems/vcpkg.cmake" `
    "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=D:/vcpkg_folders/no_msvc/triplets/x64-win-llvm.cmake" `
    "-DVCPKG_TARGET_TRIPLET=x64-win-llvm" `
    "-DVCPKG_HOST_TRIPLET=x64-win-llvm" `
    "-DCMAKE_BUILD_TYPE=Release"

