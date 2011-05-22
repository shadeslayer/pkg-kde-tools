project(pkg-kde-tools)
# 2.6.4 has PERL_VENDORLIB
cmake_minimum_required(VERSION 2.6.4)

# Find required perl bits
find_package(PerlLibs)
if (PERL_VENDORLIB AND PERL_EXECUTABLE)
    MESSAGE(STATUS "Perl VendorLib: ${PERL_VENDORLIB}")
else (PERL_VENDORLIB AND PERL_EXECUTABLE)
    MESSAGE(FATAL_ERROR "Unable to determine vendorlib. Perl was not found?")
endif (PERL_VENDORLIB AND PERL_EXECUTABLE)

find_program(POD2MAN pod2man)
if (NOT POD2MAN)
    MESSAGE(FATAL_ERROR "pod2man is required to build this package")
endif (NOT POD2MAN)

set(BIN_INSTALL_DIR bin CACHE PATH "Binary/script installation directory")
set(LIB_INSTALL_DIR lib CACHE PATH "Library installation directory")
set(DATA_INSTALL_DIR share/${CMAKE_PROJECT_NAME} CACHE PATH "Data file installation directory")
set(DATALIB_INSTALL_DIR "${DATA_INSTALL_DIR}/lib")
set(MAN_INSTALL_DIR share/man CACHE PATH "Manual page installation directory")
option(DISABLE_TESTS "Disable ${CMAKE_PROJECT_NAME} tests" OFF)

# Function for building & installing manual pages generated from PODs
function(install_pod_manpages section)
    foreach (pod ${ARGN})
        set(man "${CMAKE_CURRENT_BINARY_DIR}/${pod}.${section}")
        add_custom_command(OUTPUT "${man}"
            COMMAND ${POD2MAN} "${CMAKE_CURRENT_SOURCE_DIR}/${pod}" "${man}"
            MAIN_DEPENDENCY ${pod})
        get_filename_component(podfilename ${pod} NAME)
        add_custom_target(pod2man_${pod} ALL DEPENDS ${man}
            COMMENT "Building manual page for ${pod}" SOURCES ${pod})
        install(FILES ${man} DESTINATION "${MAN_INSTALL_DIR}/man${section}"
                             COMPONENT Documentation)
    endforeach (pod ${ARGN})
endfunction(install_pod_manpages section)

# Install data & arch-indep library bundles
install(DIRECTORY cmake makefiles qt-kde-team
        DESTINATION ${DATA_INSTALL_DIR}
        COMPONENT Programs)

install(DIRECTORY vcslib/
    DESTINATION ${DATA_INSTALL_DIR}/vcs
    COMPONENT Programs)

install(DIRECTORY datalib/
    DESTINATION ${DATALIB_INSTALL_DIR}
    COMPONENT Programs)

install(DIRECTORY perllib/
    DESTINATION ${PERL_VENDORLIB}
    COMPONENT Programs
    FILES_MATCHING PATTERN "*.pm")

# Install debhelper helpers programs
install(PROGRAMS
    dh_movelibkdeinit
    dh_sameversiondep
    dh_sodeps
    DESTINATION ${BIN_INSTALL_DIR}
    COMPONENT Programs
)
install_pod_manpages(1 dh_movelibkdeinit dh_sameversiondep dh_sodeps)

# Install pkgkde binaries
install(PROGRAMS
    pkgkde-debs2symbols
    pkgkde-gensymbols
    pkgkde-getbuildlogs
    pkgkde-override-sc-dev-latest
    pkgkde-symbolshelper
    pkgkde-vcs
    DESTINATION ${BIN_INSTALL_DIR}
    COMPONENT Programs)
install_pod_manpages(1 pkgkde-override-sc-dev-latest)

# Install raw manpages
install(DIRECTORY man1
    DESTINATION ${MAN_INSTALL_DIR}
    COMPONENT Documentation)

if (NOT DISABLE_TESTS)
    enable_testing()
    add_subdirectory(t)
endif (NOT DISABLE_TESTS)
