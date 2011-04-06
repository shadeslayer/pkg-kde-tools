# Copyright (C) 2011 Modestas Vainius <modax@debian.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

set(DEBABI_VERSION_PREFIX abi CACHE STRING "Prefix for custom SOVERSIONs and symbol versions")

function(DEBABI_SPLIT_PKGNAME pkg targetvar soversionvar)
    set(t "")
    set(pkgsv "")
    if (DEFINED debabi_${pkg}_CMake-Target)
        set(t "${debabi_${pkg}_CMake-Target}")
    else (DEFINED debabi_${pkg}_CMake-Target)
        # Strip abi suffix if needed
        if (debabi_${pkg}_Debian-ABI GREATER 0)
            string(REGEX REPLACE "${DEBABI_VERSION_PREFIX}[0-9]+$" "" pkg_noabi ${pkg})
        else (debabi_${pkg}_Debian-ABI GREATER 0)
            set(pkg_noabi ${pkg})
        endif (debabi_${pkg}_Debian-ABI GREATER 0)
        # Parse package name
        if (${pkg_noabi} MATCHES "^lib(.*[^0-9][0-9]+)-([0-9]+)[a-f]?$")
            set(t ${CMAKE_MATCH_1})
            set(pkgsv ${CMAKE_MATCH_2})
        elseif (${pkg_noabi} MATCHES "^lib(.*[^0-9])([0-9]+)[a-f]?$")
            set(t ${CMAKE_MATCH_1})
            set(pkgsv ${CMAKE_MATCH_2})
        endif (${pkg_noabi} MATCHES "^lib(.*[^0-9][0-9]+)-([0-9]+)[a-f]?$")
    endif (DEFINED debabi_${pkg}_CMake-Target)
    if (t STREQUAL "" OR NOT(TARGET ${t}))
        message(STATUS "DebianABIManager: unable to find CMake target '${t}' for package '${pkg}'. Please set X-CMake-Target")
        return()
    endif (t STREQUAL "" OR NOT(TARGET ${t}))

    # Extract current SOVERSION from the target
    get_target_property(tgttype ${t} TYPE)
    get_target_property(tgtsv ${t} SOVERSION)
    if (NOT (tgtsv OR tgttype STREQUAL "SHARED_LIBRARY"))
        message(STATUS "DebianABIManager: CMake target '${t}' (package '${pkg}') is not valid shared library target")
        return()
    endif (NOT (tgtsv OR tgttype STREQUAL "SHARED_LIBRARY"))

    # If X-CMake-Target was used, simply trust target SOVERSION.
    # Otherwise compare if package name matches SOVERSION property.
    if (pkgsv STREQUAL "" OR pkgsv STREQUAL tgtsv)
        set(${targetvar} ${t} PARENT_SCOPE)
        set(${soversionvar} ${tgtsv} PARENT_SCOPE)
    else (pkgsv STREQUAL "" OR pkgsv STREQUAL tgtsv)
        message(STATUS "DebianABIManager: CMake target '${t}' SOVERSION does not match package name '${pkg}'")
    endif (pkgsv STREQUAL "" OR pkgsv STREQUAL tgtsv)
endfunction(DEBABI_SPLIT_PKGNAME pkg targetvar soversionvar)

if (CMAKE_BUILD_TYPE AND CMAKE_BUILD_TYPE STREQUAL "Debian")
    # Parse debian/control
    get_filename_component(debabi_dirname ${CMAKE_CURRENT_LIST_FILE} PATH)
    execute_process(
        COMMAND ${debabi_dirname}/debcontrol2cmake.pl -sdebabi_ -FDebian-ABI -FCMake-Target
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/debabi_control
    )
    include(${CMAKE_CURRENT_BINARY_DIR}/debabi_control)

    # Process packages which debcontrol2cmake returned
    set(debabi_okpkgs "")
    set(debabi_failedpkgs "")
    foreach (debabi_pkg ${debabi_packages})
        if (DEFINED debabi_${debabi_pkg}_Debian-ABI)
            unset(debabi_target)
            # Try spliting package name
            debabi_split_pkgname(${debabi_pkg} debabi_target debabi_origsoversion)
            if (debabi_target)
                set(debabi_${debabi_pkg}_CMake-Target ${debabi_target}) # for success log

                # Do not add SOVERSION / VERSION suffix if ABI is 0
                if (${debabi_${debabi_pkg}_Debian-ABI} GREATER 0)
                    set(debabi_soversion "${debabi_origsoversion}${DEBABI_VERSION_PREFIX}${debabi_${debabi_pkg}_Debian-ABI}")
                    set_target_properties(${debabi_target} PROPERTIES SOVERSION "${debabi_soversion}")
                    get_target_property(debabi_version ${debabi_target} VERSION)
                    if (debabi_version)
                        set(debabi_version "${debabi_version}.${DEBABI_VERSION_PREFIX}${debabi_${debabi_pkg}_Debian-ABI}")
                        set_target_properties(${debabi_target} PROPERTIES VERSION "${debabi_version}")
                    endif (debabi_version)
                endif (${debabi_${debabi_pkg}_Debian-ABI} GREATER 0)

                # Generate symbol version. Do it always even if ABI is 0. So ABI_4_0, ABI_4_1, ...
                string(TOUPPER "${DEBABI_VERSION_PREFIX}" debabi_symver)
                set(debabi_symver "${debabi_symver}_${debabi_origsoversion}_${debabi_${debabi_pkg}_Debian-ABI}")
                set_target_properties(${debabi_target} PROPERTIES DEBABI_SYMVER ${debabi_symver})

                # Now add symbol version (via --version-script) to the linker command line
                get_target_property(debabi_link_flags ${debabi_target} LINK_FLAGS_DEBIAN)
                if (NOT(debabi_link_flags) OR (debabi_link_flags STREQUAL "NOTFOUND"))
                    set(debabi_link_flags "")
                endif (NOT(debabi_link_flags) OR (debabi_link_flags STREQUAL "NOTFOUND"))
                set(debabi_verscript "${CMAKE_CURRENT_BINARY_DIR}/debabi_verscript_${debabi_target}")
                configure_file("${debabi_dirname}/debabi_verscript.cmake" "${debabi_verscript}" @ONLY)
                set(debabi_link_flags "${debabi_link_flags} -Wl,--version-script,${debabi_verscript}")
                set_target_properties(${debabi_target} PROPERTIES LINK_FLAGS_DEBIAN ${debabi_link_flags})

                list(APPEND debabi_okpkgs ${debabi_pkg})
            else (debabi_target)
                list(APPEND debabi_failedpkgs ${debabi_pkg})
            endif (debabi_target)
        endif (DEFINED debabi_${debabi_pkg}_Debian-ABI)
    endforeach (debabi_pkg ${debabi_packages})

    if (debabi_failedpkgs)
        string(REPLACE ";" " " debabi_errpkgs "${debabi_failedpkgs}")
        message(SEND_ERROR "DebianABIManager: failed packages: ${debabi_errpkgs}")
    elseif (debabi_okpkgs)
        message("-------------------------------------------------------------------")
        message("-- DebianABIManager: successfully processed the following packages:")
        message("-------------------------------------------------------------------")
        foreach (debabi_pkg ${debabi_okpkgs})
            get_target_property(debabi_soversion ${debabi_${debabi_pkg}_CMake-Target} SOVERSION)
            get_target_property(debabi_version ${debabi_${debabi_pkg}_CMake-Target} VERSION)
            get_target_property(debabi_symver ${debabi_${debabi_pkg}_CMake-Target} DEBABI_SYMVER)
            message("   * ${debabi_pkg} - SOVERSION: ${debabi_soversion}; VERSION: ${debabi_version}; SYMVER: ${debabi_symver}")
        endforeach (debabi_pkg ${debabi_okpkgs})
    endif (debabi_failedpkgs)
endif (CMAKE_BUILD_TYPE AND CMAKE_BUILD_TYPE STREQUAL "Debian")

