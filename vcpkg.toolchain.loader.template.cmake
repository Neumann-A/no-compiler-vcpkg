# Mark variables as used so cmake doesn't complain about them
mark_as_advanced(CMAKE_TOOLCHAIN_FILE)
include_guard(GLOBAL)
# NOTE: to figure out what cmake versions are required for different things,
# grep for `CMake 3`. All version requirement comments should follow that format.

# Attention: Changes to this file do not affect ABI hashing.

# Hardcode settings in loader:
set(VCPKG_INSTALLED_DIR "@VCPKG_INSTALLED_DIR@")
set(VCPKG_TARGET_TRIPLET "@VCPKG_TARGET_TRIPLET@")
set(VCPKG_HOST_TRIPLET "@VCPKG_HOST_TRIPLET@")
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "@VCPKG_CHAINLOAD_TOOLCHAIN_FILE@")

if(VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
    include("${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}" NO_POLICY_SCOPE)
endif()


cmake_policy(PUSH)
cmake_policy(VERSION 3.16)

include(CMakeDependentOption)

#If CMake does not have a mapping for MinSizeRel and RelWithDebInfo in imported targets
#it will map those configuration to the first valid configuration in CMAKE_CONFIGURATION_TYPES or the targets IMPORTED_CONFIGURATIONS.
#In most cases this is the debug configuration which is wrong.
if(NOT DEFINED CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL)
    set(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL "MinSizeRel;Release;None;")
endif()
if(NOT DEFINED CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO)
    set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO "RelWithDebInfo;Release;None;")
endif()

function(z_vcpkg_add_vcpkg_to_cmake_path list suffix)
    set(vcpkg_paths
        "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}${suffix}"
        "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug${suffix}"
    )
    if(NOT DEFINED CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE MATCHES "^[Dd][Ee][Bb][Uu][Gg]$")
        list(REVERSE vcpkg_paths) # Debug build: Put Debug paths before Release paths.
    endif()
    list(INSERT "${list}" "0" "${vcpkg_paths}") # CMake 3.15 is required for list(PREPEND ...).
    set("${list}" "${${list}}" PARENT_SCOPE)
endfunction()
z_vcpkg_add_vcpkg_to_cmake_path(CMAKE_PREFIX_PATH "")
z_vcpkg_add_vcpkg_to_cmake_path(CMAKE_LIBRARY_PATH "/lib/manual-link")
z_vcpkg_add_vcpkg_to_cmake_path(CMAKE_FIND_ROOT_PATH "")

set(CMAKE_FIND_FRAMEWORK "LAST") # we assume that frameworks are usually system-wide libs, not vcpkg-built
set(CMAKE_FIND_APPBUNDLE "LAST") # we assume that appbundles are usually system-wide libs, not vcpkg-built

# If one CMAKE_FIND_ROOT_PATH_MODE_* variables is set to ONLY, to  make sure that ${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}
# and ${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug are searched, it is not sufficient to just add them to CMAKE_FIND_ROOT_PATH,
# as CMAKE_FIND_ROOT_PATH specify "one or more directories to be prepended to all other search directories", so to make sure that
# the libraries are searched as they are, it is necessary to add "/" to the CMAKE_PREFIX_PATH
if(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE STREQUAL "ONLY" OR
   CMAKE_FIND_ROOT_PATH_MODE_LIBRARY STREQUAL "ONLY" OR
   CMAKE_FIND_ROOT_PATH_MODE_PACKAGE STREQUAL "ONLY")
   list(APPEND CMAKE_PREFIX_PATH "/")
endif()

set(VCPKG_CMAKE_FIND_ROOT_PATH "${CMAKE_FIND_ROOT_PATH}")

option(VCPKG_SETUP_CMAKE_PROGRAM_PATH  "Enable the setup of CMAKE_PROGRAM_PATH to vcpkg paths" ON)
cmake_dependent_option(VCPKG_USE_HOST_TOOLS "Setup CMAKE_PROGRAM_PATH to use host tools" ON "VCPKG_CAN_USE_HOST_TOOLS" OFF)
unset(VCPKG_CAN_USE_HOST_TOOLS)

if(VCPKG_SETUP_CMAKE_PROGRAM_PATH)
    block(PROPAGATE CMAKE_PROGRAM_PATH)
        set(tools_base_path "${VCPKG_INSTALLED_DIR}/${VCPKG_HOST_TRIPLET}/tools")
        list(APPEND CMAKE_PROGRAM_PATH "${tools_base_path}")
        file(GLOB Z_VCPKG_TOOLS_DIRS LIST_DIRECTORIES true "${tools_base_path}/*")
        file(GLOB Z_VCPKG_TOOLS_FILES LIST_DIRECTORIES false "${tools_base_path}/*")
        file(GLOB Z_VCPKG_TOOLS_DIRS_BIN LIST_DIRECTORIES true "${tools_base_path}/*/bin")
        file(GLOB Z_VCPKG_TOOLS_FILES_BIN LIST_DIRECTORIES false "${tools_base_path}/*/bin")
        list(REMOVE_ITEM Z_VCPKG_TOOLS_DIRS ${Z_VCPKG_TOOLS_FILES} "") # need at least one item for REMOVE_ITEM if CMake <= 3.19
        list(REMOVE_ITEM Z_VCPKG_TOOLS_DIRS_BIN ${Z_VCPKG_TOOLS_FILES_BIN} "")
        string(REPLACE "/bin" "" Z_VCPKG_TOOLS_DIRS_TO_REMOVE "${Z_VCPKG_TOOLS_DIRS_BIN}")
        list(REMOVE_ITEM Z_VCPKG_TOOLS_DIRS ${Z_VCPKG_TOOLS_DIRS_TO_REMOVE} "")
        list(APPEND Z_VCPKG_TOOLS_DIRS ${Z_VCPKG_TOOLS_DIRS_BIN})
        foreach(Z_VCPKG_TOOLS_DIR IN LISTS Z_VCPKG_TOOLS_DIRS)
            list(APPEND CMAKE_PROGRAM_PATH "${Z_VCPKG_TOOLS_DIR}")
        endforeach()
    endblock()
endif()

cmake_policy(POP)

option(VCPKG_TRACE_FIND_PACKAGE "Trace calls to find_package()" OFF)

# NOTE: this is not a function, which means that arguments _are not_ perfectly forwarded
# this is fine for `find_package`, since there are no usecases for `;` in arguments,
# so perfect forwarding is not important
set(z_vcpkg_find_package_backup_id "0")
macro("find_package" z_vcpkg_find_package_package_name)
    if(VCPKG_TRACE_FIND_PACKAGE)
        string(REPEAT "  " "${z_vcpkg_find_package_backup_id}" z_vcpkg_find_package_indent)
        string(JOIN " " z_vcpkg_find_package_argn ${ARGN})
        message(STATUS "${z_vcpkg_find_package_indent}find_package(${z_vcpkg_find_package_package_name} ${z_vcpkg_find_package_argn})")
        unset(z_vcpkg_find_package_argn)
        unset(z_vcpkg_find_package_indent)
    endif()

    math(EXPR z_vcpkg_find_package_backup_id "${z_vcpkg_find_package_backup_id} + 1")
    set(z_vcpkg_find_package_package_name "${z_vcpkg_find_package_package_name}")
    set(z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_ARGN "${ARGN}")
    set(z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_vars "")

    # Workaround to set the ROOT_PATH until upstream CMake stops overriding
    # the ROOT_PATH at apple OS initialization phase.
    # See https://gitlab.kitware.com/cmake/cmake/merge_requests/3273
    # Fixed in CMake 3.15
    if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
        list(APPEND z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_vars "CMAKE_FIND_ROOT_PATH")
        if(DEFINED CMAKE_FIND_ROOT_PATH)
            set(z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_CMAKE_FIND_ROOT_PATH "${CMAKE_FIND_ROOT_PATH}")
        endif()
        list(APPEND CMAKE_FIND_ROOT_PATH "${VCPKG_CMAKE_FIND_ROOT_PATH}")
    endif()

    string(TOLOWER "${z_vcpkg_find_package_package_name}" z_vcpkg_find_package_lowercase_package_name)
    set(z_vcpkg_find_package_vcpkg_cmake_wrapper_path
        "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/share/${z_vcpkg_find_package_lowercase_package_name}/vcpkg-cmake-wrapper.cmake")
    if(EXISTS "${z_vcpkg_find_package_vcpkg_cmake_wrapper_path}")
        if(VCPKG_TRACE_FIND_PACKAGE)
            string(REPEAT "  " "${z_vcpkg_find_package_backup_id}" z_vcpkg_find_package_indent)
            message(STATUS "${z_vcpkg_find_package_indent}using share/${z_vcpkg_find_package_lowercase_package_name}/vcpkg-cmake-wrapper.cmake")
            unset(z_vcpkg_find_package_indent)
        endif()
        list(APPEND z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_vars "ARGS")
        if(DEFINED ARGS)
            set(z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_ARGS "${ARGS}")
        endif()
        set(ARGS "${z_vcpkg_find_package_package_name};${z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_ARGN}")
        include("${z_vcpkg_find_package_vcpkg_cmake_wrapper_path}")
    else()
        _find_package("${z_vcpkg_find_package_package_name}" ${z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_ARGN})
    endif()
    # Do not use z_vcpkg_find_package_package_name beyond this point since it might have changed!
    # Only variables using z_vcpkg_find_package_backup_id can used correctly below!
    foreach(z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_var IN LISTS z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_vars)
        if(DEFINED z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_${z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_var})
            set("${z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_var}" "${z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_${z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_var}}")
        else()
            unset("${z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_var}")
        endif()
        unset("z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_${z_vcpkg_find_package_${z_vcpkg_find_package_backup_id}_backup_var}")
    endforeach()
    math(EXPR z_vcpkg_find_package_backup_id "${z_vcpkg_find_package_backup_id} - 1")
    if(z_vcpkg_find_package_backup_id LESS "0")
        message(FATAL_ERROR "[vcpkg]: find_package ended with z_vcpkg_find_package_backup_id being less than 0! This is a logical error and should never happen. Please provide a cmake trace log via cmake cmd line option '--trace-expand'!")
    endif()
endmacro()

set(Z_VCPKG_UNUSED "${CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION}")
set(Z_VCPKG_UNUSED "${CMAKE_EXPORT_NO_PACKAGE_REGISTRY}")
set(Z_VCPKG_UNUSED "${CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY}")
set(Z_VCPKG_UNUSED "${CMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY}")
set(Z_VCPKG_UNUSED "${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP}")

# Determine whether the toolchain is loaded during a try-compile configuration
get_property(Z_VCPKG_CMAKE_IN_TRY_COMPILE GLOBAL PROPERTY IN_TRY_COMPILE)
# Propagate these values to try-compile configurations so the triplet and toolchain load
if(NOT Z_VCPKG_CMAKE_IN_TRY_COMPILE)
    list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
        VCPKG_TARGET_TRIPLET
        VCPKG_HOST_TRIPLET
        VCPKG_INSTALLED_DIR
        VCPKG_CHAINLOAD_TOOLCHAIN_FILE
    )
endif()
