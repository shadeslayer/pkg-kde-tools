#include <stdio.h>
#include "testdlr.h"

int testdlr_plugin_func() {
    printf("++ " PLUGIN_NAME ": START ++\n");

    testdlr_lib1_func();

    printf("++ " PLUGIN_NAME ": END ++\n");
    return 0;
}
