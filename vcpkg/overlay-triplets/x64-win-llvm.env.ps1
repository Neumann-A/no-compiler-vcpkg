Param(
  [Parameter(Mandatory = $true)]
  [String]
  $VcpkgInstalledDir
)

. $VcpkgInstalledDir/x64-win-llvm/env-setup/llvm-env.ps1
Write-Host "Environment setup for the x64-win-llvm triplet!"