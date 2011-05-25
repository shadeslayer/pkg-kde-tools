project(DLRestrictions C)

add_library(dlrestrictions SHARED
    dlrestrictions.c
    dlrestrictions.h)
set_target_properties(dlrestrictions PROPERTIES SOVERSION 1 VERSION 1.0.0)
# FIXME: portability
set_target_properties(dlrestrictions PROPERTIES LINK_FLAGS "-Wl,--default-symver")
target_link_libraries(dlrestrictions ${CMAKE_DL_LIBS})
target_link_libraries(dlrestrictions LINK_INTERFACE_LIBRARIES "")

install(TARGETS dlrestrictions
    EXPORT dlrestrictions
    LIBRARY DESTINATION ${LIB_INSTALL_DIR}
    COMPONENT DLRestrictions)
install(FILES dlrestrictions.h
    DESTINATION ${INCLUDE_INSTALL_DIR}
    COMPONENT DLRestrictions)
install(FILES DLRestrictionsConfig.cmake dlrestrictions-symbol.c.cmake
    DESTINATION ${LIB_INSTALL_DIR}/cmake/DLRestrictions)
install(EXPORT dlrestrictions FILE dlrestrictions-export.cmake
    DESTINATION ${LIB_INSTALL_DIR}/cmake/DLRestrictions)
