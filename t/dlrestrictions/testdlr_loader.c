#include <dlfcn.h>
#include <stdio.h>
#include <dlrestrictions.h>

#include "testdlr.h"

static int execute_plugin(void *handle)
{
    int r;
    testdlr_plugin_func_t f;

    r = -1;
    if (handle != NULL) {
        f = dlsym(handle, PLUGIN_FUNC);
        if (f != NULL) {
            r = f();
        }
        return r;
    }

    return -1;
}

static int load_plugin_no_dlr(const char *file) {
    void *plugin;
    int r;

    r = -1;
    plugin = dlopen(file, RTLD_LAZY | RTLD_LOCAL);
    if (plugin != NULL) {
        if ((r = execute_plugin(plugin)) < 0) {
            printf(LOADER_NAME ":load_plugin_no_dlr: FAILED " PLUGIN_FUNC "\n");
        }
        dlclose(plugin);
    } else {
        printf(LOADER_NAME ":load_plugin_no_dlr: FAILED dlopen\n");
    }
    return r;
}

static int load_plugin_with_dlr(const char *file, int fail_on_error) {
    void *plugin;
    int r;

    r = -1;
    plugin = dlr_dlopen_extended(file, RTLD_LAZY | RTLD_LOCAL, 1, fail_on_error);
    if (plugin != NULL) {
        if ((r = execute_plugin(plugin)) < 0) {
            printf(LOADER_NAME ":load_plugin_with_dlr: FAILED " PLUGIN_FUNC "\n");
        }
        dlclose(plugin);
    } else {
        printf(LOADER_NAME ":load_plugin_with_dlr: FAILED dlr_dlopen_extended\n");
    }
    return r;
}

static int dlopen_lib(int fail_on_error) {
    void *lib;
    int r;

    r = -1;
    dlr_set_symbol_name(DLR_SYMBOL_NAME);
    lib = dlr_dlopen_extended("libtestdlr_lib.so.2", RTLD_LAZY | RTLD_LOCAL, 1, fail_on_error);
    if (lib != NULL) {
        dlclose(lib);
    } else {
        printf(PLUGIN_NAME ":dlopen_lib() FAILED\n");
    }
    return r;
}


int main(int argc, char** argv)
{
    int r;

    printf("-- " LOADER_NAME ": START --\n");

/*    testdlr_lib1_func();*/
    testdlr_lib2_func();
/*    r = load_plugin_no_dlr();*/

//    dlr_set_symbol_name("boo");
    r = load_plugin_with_dlr(PLUGIN_FILE(""), 0);
//    r = load_plugin_with_dlr(PLUGIN_FILE("2"), 0);
    //dlopen_lib(0);

    printf("-- " LOADER_NAME ": END --\n");

    return (r < 0) ? 1 : 0;
}
