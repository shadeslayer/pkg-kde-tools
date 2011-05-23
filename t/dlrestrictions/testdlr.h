#ifndef _DLRTLIB_H_
#define _DLRTLIB_H_

#define LOADER_NAME "testdlr_loader"
#define PLUGIN_NAME "testdlr_plugin"
#define PLUGIN_FILE(n) "./" PLUGIN_NAME n ".so"
#define PLUGIN_FUNC "testdlr_plugin_func"

void testdlr_deeplib1_func();
void testdlr_deeplib2_func();

void testdlr_lib1_func();
void testdlr_lib2_func();

typedef int (*testdlr_plugin_func_t)();

#endif
