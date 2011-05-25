set(DLRESTRICTIONS_FOUND 1)

set(DEFAULT_DLRESTRICTIONS "" CACHE STRING
    "Enable generation of the DLRestrictions symbol with such a value by default.")
define_property(TARGET PROPERTY DLRESTRICTIONS
    BRIEF_DOCS "Value of the DLRestrictions symbol for this target."
    FULL_DOCS "Define DLRestrictions symbol for this target with a value of this property.
    Overrides global DEFAULT_DLRESTRICTIONS. Set to empty string in order to turn
    off symbol generation for the target.")

set(DLRESTRICTIONS_SYMBOL_SOURCE_FILE "${DLRestrictions_DIR}/dlrestrictions-symbol.c.cmake")
set(DLRESTRICTIONS_EXPORT_FILE "${DLRestrictions_DIR}/dlrestrictions-export.cmake")

# Export file might not exist if DLRestrictions is referred from the unit tests
if (EXISTS "${DLRESTRICTIONS_EXPORT_FILE}")
    # Include export file
    include(${DLRESTRICTIONS_EXPORT_FILE})
endif (EXISTS "${DLRESTRICTIONS_EXPORT_FILE}")

function(DLRESTRICTIONS_PROCESS_TARGETS)
    foreach(target ${ARGN})
        get_target_property(dlr_expression "${target}" DLRESTRICTIONS)
        if (dlr_expression MATCHES "NOTFOUND$" AND DEFAULT_DLRESTRICTIONS)
            set(dlr_expression "${DEFAULT_DLRESTRICTIONS}")
        endif (dlr_expression MATCHES "NOTFOUND$" AND DEFAULT_DLRESTRICTIONS)

        if (dlr_expression)
            # Add symbol to the library
            set(dlr_target "dlrestrictions_${target}")
            set(dlr_target_file "${CMAKE_CURRENT_BINARY_DIR}/${dlr_target}.c")
            configure_file("${DLRESTRICTIONS_SYMBOL_SOURCE_FILE}" "${dlr_target_file}" @ONLY)
            add_library(${dlr_target} STATIC "${dlr_target_file}")
            get_property(dlr_target_type TARGET ${target} PROPERTY TYPE)
            if (${dlr_target_type} MATCHES "^(SHARED|MODULE)_LIBRARY$")
                set_property(TARGET ${dlr_target} PROPERTY COMPILE_FLAGS "${CMAKE_SHARED_LIBRARY_C_FLAGS}" APPEND)
            endif (${dlr_target_type} MATCHES "^(SHARED|MODULE)_LIBRARY$")
            add_dependencies(${target} ${dlr_target})
            set_property(TARGET ${dlr_target} PROPERTY EchoString "Adding DLRestrictions (=${dlr_expression}) for ${target}")
            get_property(dlr_target_location TARGET ${dlr_target} PROPERTY LOCATION)
            get_property(target_link_flags TARGET ${target} PROPERTY LINK_FLAGS)
            # FIXME: not portable
            # NOTE: target_link_libraries() can't be used outside a directory the target is defined in
            set_property(TARGET ${target} PROPERTY LINK_FLAGS
                "${target_link_flags} -Wl,--whole-archive '${dlr_target_location}' -Wl,--no-whole-archive")
        endif (dlr_expression)
    endforeach(target ${ARGN})
endfunction(DLRESTRICTIONS_PROCESS_TARGETS)
