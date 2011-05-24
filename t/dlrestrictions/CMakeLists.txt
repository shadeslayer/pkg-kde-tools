project(DLRestrictions_tests)

find_package(DLRestrictions REQUIRED NO_MODULE PATHS
    "${DLRestrictions_SOURCE_DIR}"
    "${DLRestrictions_BINARY_DIR}" NO_DEFAULT_PATH)

include_directories(${DLRestrictions_SOURCE_DIR})

add_library(testdlr_deeplib1 SHARED testdlr_deeplib1.c)
set_target_properties(testdlr_deeplib1 PROPERTIES
    OUTPUT_NAME "testdlr_deeplib"
    SOVERSION 1
    VERSION 1.0.0
)

add_library(testdlr_lib1 SHARED testdlr_lib1.c)
set_target_properties(testdlr_lib1 PROPERTIES
    OUTPUT_NAME "testdlr_lib"
    SOVERSION 1
    VERSION 1.0.0
    DEBIAN_DLRESTRICTIONS "REJECT:OTHERSOVERSION"
)
target_link_libraries(testdlr_lib1 testdlr_deeplib1)
debian_add_dlrestrictions_symbol(testdlr_lib1)

add_library(testdlr_deeplib2 SHARED testdlr_deeplib2.c)
set_target_properties(testdlr_deeplib2 PROPERTIES
    OUTPUT_NAME "testdlr_deeplib"
    SOVERSION 2
    VERSION 2.0.0
)

add_library(testdlr_lib2 SHARED testdlr_lib2.c)
set_target_properties(testdlr_lib2 PROPERTIES
    OUTPUT_NAME "testdlr_lib"
    SOVERSION 2
    VERSION 2.0.0
)
target_link_libraries(testdlr_lib2 testdlr_deeplib1)

add_library(testdlr_plugin SHARED testdlr_plugin.c)
set_target_properties(testdlr_plugin PROPERTIES
    PREFIX ""
    SUFFIX ".so"
)
target_link_libraries(testdlr_plugin testdlr_lib1)

add_library(testdlr_plugin2 SHARED testdlr_plugin.c)
set_target_properties(testdlr_plugin2 PROPERTIES
    PREFIX ""
    SUFFIX ".so"
)
target_link_libraries(testdlr_plugin2 testdlr_lib1)

add_executable(testdlr_loader testdlr_loader.c)
target_link_libraries(testdlr_loader testdlr_lib2 ${CMAKE_DL_LIBS} dlrestrictions)
