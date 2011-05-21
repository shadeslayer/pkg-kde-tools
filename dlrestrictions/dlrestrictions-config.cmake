set(DEBIAN_DLRESTRICTIONS "" CACHE STRING
    "Enable generation of the DLRestrictions symbol with such a value by default.")
define_property(TARGET PROPERTY DEBIAN_DLRESTRICTIONS
    BRIEF_DOCS "Value of the DLRestrictions symbol for this target."
    FULL_DOCS "Define DLRestrictions symbol for this target with a value of this property.
    Overrides global DEBIAN_DLRESTRICTIONS. Set to empty string in order to turn off
    symbol generation for the target.")

set(DLRESTRICTIONS_SYMBOL_C "${DLRestrictions_DIR}/dlrestrictions-symbol.c.cmake")
set(DLRESTRICTIONS_EXPORT_FILE ${DLRestrictions_DIR}/dlrestrictions-export.cmake)

if (EXISTS "${DLRESTRICTIONS_EXPORT_FILE}")
    # Include export file
    include(${DLRESTRICTIONS_EXPORT_FILE})
endif (EXISTS "${DLRESTRICTIONS_EXPORT_FILE}")

function(DEBIAN_ADD_DLRESTRICTIONS_SYMBOL)
    foreach(target ${ARGN})
        get_target_property(value "${target}" DEBIAN_DLRESTRICTIONS)
        if (value MATCHES "NOTFOUND$" AND DEBIAN_DLRESTRICTIONS)
            set(value "${DEBIAN_DLRESTRICTIONS}")
        endif (value MATCHES "NOTFOUND$" AND DEBIAN_DLRESTRICTIONS)

        if (value)
            # Add symbol to the library
            set(sc_target "dlrestrictions_${target}")
            set(sc_source_file "${CMAKE_CURRENT_BINARY_DIR}/${sc_target}.c")
            configure_file("${DLRESTRICTIONS_SYMBOL_C}" "${sc_source_file}" @ONLY)
            add_library(${sc_target} STATIC "${sc_source_file}")
            get_property(target_type TARGET ${target} PROPERTY TYPE)
            if (${target_type} STREQUAL "SHARED_LIBRARY")
                set_property(SOURCE ${sc_target} PROPERTY COMPILE_FLAGS "${CMAKE_SHARED_LIBRARY_C_FLAGS}" APPEND)
            endif (${target_type} STREQUAL "SHARED_LIBRARY")
            set_property(TARGET ${sc_target} PROPERTY EchoString "Adding DLRestrictions symbol (=${value}) for ${target}")
            target_link_libraries(${target} -Wl,--whole-archive ${sc_target} -Wl,--no-whole-archive)
        endif (value)
    endforeach(target ${ARGN})
endfunction(DEBIAN_ADD_DLRESTRICTIONS_SYMBOL)
