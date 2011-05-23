function(add_perl_test path)
    get_filename_component(filename "${path}" NAME)
    string(REGEX REPLACE "\\.t$" "" testname ${filename})

    # Custom working directory
    set(cmd_prefix)
    if (ARGV1)
        set(cmd_prefix ${CMAKE_COMMAND} -E chdir ${ARGV1})
    endif (ARGV1)
    add_test(${testname}
        ${cmd_prefix} ${CMAKE_SOURCE_DIR}/run-local ${PERL_EXECUTABLE} -MTest::Harness
        -e "$Test::Harness::verbose=\\\$ENV{VERBOSE}||0; runtests '${path}'")
endfunction(add_perl_test path)

# Syntax check of perl modules and scripts
add_perl_test("${CMAKE_CURRENT_SOURCE_DIR}/perl_syntax_check.t" "${CMAKE_SOURCE_DIR}")

add_subdirectory(dlrestrictions)
