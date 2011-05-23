#include <stdio.h>
#include "testdlr.h"

#include <dlfcn.h>
#include <dlrestrictions.h>

static int dlopen_lib(int fail_on_error) {
    void *lib;
    int r;

    r = -1;
    dlr_set_symbol_name(DLR_SYMBOL_NAME);
    lib = dlr_dlopen_extended("libtestdlr_lib.so.1", RTLD_LAZY | RTLD_LOCAL, 1, fail_on_error);
    if (lib != NULL) {
        dlclose(lib);
    } else {
        printf(PLUGIN_NAME ":dlopen_lib() FAILED\n");
    }
    return r;
}

void testdlr_lib1_func()
{
    printf("testdlr_lib1: testdlr_lib1_func() called\n");
    testdlr_deeplib1_func();
    //dlopen_lib(1);
}
