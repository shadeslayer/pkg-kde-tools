/*
    Copyright (C) 2011  Modestas Vainius <modax@debian.org>

    This file is part of DLRestrictions.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2.1 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef _LIBRUNTIMERESTRICTIONS_H_
#define _LIBRUNTIMERESTRICTIONS_H_

#include <sys/types.h>

#ifndef DLR_LIBRARY_NAME
#define DLR_LIBRARY_NAME            "DLRestrictions"
#endif

#define DLR_STRINGIFY(s)            #s
#define DLR_STRINGIFY2(s)           DLR_STRINGIFY(s)

#define DLR_SYMBOL                  dlrestrictions_data
#define DLR_SYMBOL_NAME             DLR_STRINGIFY2(DLR_SYMBOL)
#define DLR_SYMBOL_MAGIC             "DLR_SYMBOL_V1:"
#define MAX_DLR_EXPRESSION_LENGTH    4096

typedef struct {
    char magic[sizeof(DLR_SYMBOL_MAGIC)];
    unsigned int expression_length;
    const char *expression;
} dlr_symbol_t;

/* FIXME: proper visibility stuff */
#define DLR_EXPORT_SYMBOL(expression) \
    __attribute__((visibility("default"))) \
    const dlr_symbol_t DLR_SYMBOL = { \
        DLR_SYMBOL_MAGIC, \
        (unsigned int) sizeof(expression), \
        expression \
    }

/* Get or set the name of the DLRestrictions symbol */
void dlr_set_symbol_name(const char *name);
const char* dlr_get_symbol_name(void);

/* Error functions */
const char* dlr_error(void);
int dlr_snprintf_pretty_error(char *str, size_t n, const char *context);
void dlr_print_pretty_error(const char *context);

/* Library compatibility checking functions */

/*
   Public function for verification of the given library file against global
   symbol object.

   * file - if present, the file to dlopen(); if omitted, the handle parameter
            will be used.
   * handle - if not NULL, the handle of the dlopen()'ed file will be stored here
              (and the object won't be dlclose()'ed). If file is NULL, handle must
              be non-NULL and point to the already open shared object.
   * Return value:
      < 0 - error occured while checking compatibility:
          * -ENOENT - unable to open file;
          * -ENOTDIR - unable to dlopen() global symbol object;
          * -EPROTO - syntax or other fatal error while checking compatibility;
     == 0 - library and its dependencies are NOT compatible with global object;
      > 0 - library and its dependencies are compatible with global object;
*/
int dlr_check_file_compatibility(const char *file, void **handle);

/*
   An extended wrapper around dlopen() with integrated file compatibility checking.

   * file - same as to dlopen();
   * mode - same as to dlopen();
   * printerror - if enabled, a pretty DLRestrctions error will be printed to stderr
     when one occurs or if the file is NOT compatible.
   * fail_on_error - if enabled, NULL will be returned if DLRestrictions specific
     error occurs. Please note that successful compatibility checking regardless
     of the outcome is NOT an error.
   * Return value - a valid dlopen() handle if successful, NULL otherwise.
*/
void* dlr_dlopen_extended(const char *file, int mode, int print_error, int fail_on_error);

#endif
