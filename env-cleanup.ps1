# Define the list of whitelisted environment variables
$whitelist = @(
    "PATH", `
#    "USERPROFILE", `
    "ALLUSERSPROFILE", `
    "CommandPromptType", `
    "CommonProgramFiles", `
    "CommonProgramFiles(x86)", `
    "CommonProgramW6432", `
#    "COMPUTERNAME", `
    "ComSpec", `
#    "HOMEDRIVE", `
#    "HOMEPATH", `
    "ALLUSERSPROFILE", `
#    "LOCALAPPDATA", `
#    "LOGONSERVER", `
    "OS", `
    "PATHEXT", `
    "PROCESSOR_ARCHITECTURE", `
    "PROCESSOR_IDENTIFIER", `
    "PROCESSOR_LEVEL", `
    "PROCESSOR_REVISION", `
    "ProgramData", `
    "ProgramFiles", `
    "ProgramFiles(x86)", `
    "ProgramW6432", `
    "PROMPT", `
    "PSModulePath", `
    "PUBLIC", `
    "SystemDrive", `
    "SystemRoot", `
    "TEMP", `
    "TMP", `
#    "USERDOMAIN", `
#    "USERDOMAIN_ROAMINGPROFILE", `
#    "USERNAME", `
#    "USERPROFILE", `
    "windir", `
    "GIT_ASKPASS", `
    "VSCMD_SKIP_SENDTELEMETRY", `
    "VCPKG_COMMAND", `
    "VCPKG_TOOLCHAIN_ENV_ALREADY_SET", `
    "VCPKG_ENV_DISABLE_PROMPT", `
    "VCPKG_DOWNLOADS", `
    "VCPKG_DEFAULT_BINARY_CACHE", `
    "VCPKG_FEATURE_FLAGS", `
    "X_VCPKG_REGISTRIES_CACHE", `
    "HTTP_PROXY", `
    "HTTPS_PROXY"
) # Add more as needed

# Clear all environment variables
function global:cleanup_environment {
  $global:_envBackup = @{}
  $envVars = [System.Environment]::GetEnvironmentVariables()
  foreach ($envVar in $envVars.Keys) {
      $global:_envBackup["$envVar"] = $envVars[$envVar]
      if ($whitelist -notcontains $envVar) {
          # Backup the environment variable
          Remove-Item "Env:\$envVar" -ErrorAction SilentlyContinue
      }
  }
}

#Restore the environment
function global:restore_environment {
  foreach ($backupVar in $global:_envBackup.Keys) {
      Set-Item -Path "Env:\$backupVar" -Value $global:_envBackup[$backupVar]
  }
  Remove-Variable -Name _envBackup -Scope Global -Force
}

cleanup_environment
