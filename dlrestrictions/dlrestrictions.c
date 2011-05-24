/*
    Copyright (C) 2011  Modestas Vainius <modax@debian.org>

    This file is part of DLRestrictions.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#define _GNU_SOURCE

#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <dlfcn.h>
#include <link.h>
#include <errno.h>

#include "dlrestrictions.h"

static int debug_level;
static const char *symbol_name = DLR_SYMBOL_NAME;
static char extended_error[1024];
static unsigned char extended_error_state;

typedef struct __dlr_library {
    struct link_map *link_map;
    char *soname;
    size_t soname_l;
    char *libname;
    size_t libname_l;
    char *soversion;
    size_t soversion_l;
    struct __dlr_library *prev, *next;
} dlr_library_t;

#ifndef DLR_NO_DEBUG
static void dlr_debug(int level, const char *format, ...)
{
    va_list ap;

    if (debug_level == 0) {
        /* Cache active debug level */
        char *envvar;
        envvar = getenv("DLR_DEBUG");
        if (envvar == NULL) {
            debug_level = -1;
        } else {
            debug_level = atoi(envvar);
            if (debug_level == 0)
                debug_level = -1;
        }
    }

    if (debug_level >= level) {
        va_start(ap, format);
        fprintf(stderr, DLR_LIBRARY_NAME "(%d): ", level);
        vfprintf(stderr, format, ap);
        fprintf(stderr, "\n");
        va_end(ap);
    }
}
#else
#define dlr_debug(level, format, ...)
#endif

void dlr_set_error(const char *format, ...)
{
    va_list ap;

    va_start(ap, format);
    vsnprintf(extended_error, sizeof(extended_error), format, ap);
    va_end(ap);
    extended_error_state = 1;

}

const char* dlr_extended_error(void)
{
    if (!extended_error_state)
        return NULL;
    extended_error_state = 0;
    return extended_error;
}

void dlr_print_pretty_error(const char *context)
{
#define DLR_PRINTF_PRETTY_ERROR(format, ...) \
    fprintf(stderr, DLR_LIBRARY_NAME " error (%s): " format "\n", context, __VA_ARGS__)

    const char *dlr_err, *sys_err;

    dlr_err = dlr_extended_error();
    sys_err = (errno != 0) ? strerror(errno) : NULL;

    if (dlr_err == NULL && sys_err == NULL)
        return;

    if (dlr_err) {
        if (sys_err != NULL) {
            DLR_PRINTF_PRETTY_ERROR("%s (sys=%s)", dlr_err, sys_err);
        } else {
            DLR_PRINTF_PRETTY_ERROR("%s", dlr_err);
        }
    } else {
        DLR_PRINTF_PRETTY_ERROR("%s", sys_err);
    }
}

void dlr_set_symbol_name(const char *name)
{
    symbol_name = name;
}

const char* dlr_get_symbol_name(void)
{
    return symbol_name;
}

/* Count libraries in the structure */
static size_t dlr_count_libraries(dlr_library_t *libs)
{
    size_t c;
    for (c = 0; libs != NULL; c++, libs = libs->next);
    return c;
}

static void dlr_free_libraries(dlr_library_t *lib)
{
    dlr_library_t *next;
    while (lib != NULL) {
        next = lib->next;
        free(lib);
        lib = next;
    }
}

static dlr_library_t* dlr_parse_link_map(struct link_map *map)
{
    dlr_library_t *lib;
    char *tmp;

    /* l_name might be empty. We are not interested in such maps */
    if (map->l_name == NULL || (tmp = strrchr(map->l_name, '/')) == NULL) {
        dlr_debug(3, "link_map [%s] is not a path: skipping parsing",
                (map->l_name != NULL) ? map->l_name : "null");
        errno = ENOENT;
        return NULL;
    }

    lib = (dlr_library_t*) malloc(sizeof(dlr_library_t));
    if (lib == NULL) {
        return NULL;
    }
    lib->link_map = map;

    /* SONAME is the filename */
    lib->soname = tmp + 1;
    lib->soname_l = strlen(map->l_name) - (lib->soname - map->l_name);

    /* Parse SOVERSION and libname parts */
    lib->soversion = lib->soname;
    lib->libname = lib->soname;
    while ((tmp = strstr(lib->soversion, ".so.")) != NULL) {
        lib->soversion = tmp + 4;
        lib->libname_l = tmp - lib->soname;
    }

    /* In case SOVERSION was not found ... */
    if (lib->soversion == lib->soname) {
        dlr_debug(3, "%s SONAME is not in libNAME.so.SOVERSION format: skipping parsing",
                map->l_name);
        dlr_set_error("%s SONAME is not in libNAME.so.SOVERSION format", map->l_name);
        errno = EINVAL;
        free(lib);
        return NULL;
    }

    /* Final adjustments */
    lib->soversion_l = lib->soname_l - (lib->soversion - lib->soname);
    if (strncmp(lib->libname, "lib", 3) == 0) {
        lib->libname += 3;
        lib->libname_l -= 3;
    }

    dlr_debug(3, "link_map \"%s\" parsed: soname - %.*s; libname - %.*s; soversion - %.*s",
            map->l_name,
            (int)lib->soname_l, lib->soname,
            (int)lib->libname_l, lib->libname,
            (int)lib->soversion_l, lib->soversion);

    return lib;
}

static dlr_library_t* dlr_libraries_from_handle(void *handle)
{
    struct link_map *map;
    dlr_library_t *first, *last;
    dlr_library_t *lib;

    first = last = NULL;

    dlerror(); /* clear dl error */
    if (dlinfo(handle, RTLD_DI_LINKMAP, &map) != 0) {
        errno = ENOSYS;
        dlr_debug(1, "dlinfo(RTLD_DI_LINKMAP) failed on handle 0x%lx: %s", handle, dlerror());
        return NULL;
    }

    errno = 0;
    for (; map != NULL; map = map->l_next) {
        if ((lib = dlr_parse_link_map(map)) != NULL) {
            if (last != NULL) {
                lib->prev = last;
                lib->next = NULL;
                last->next = lib;
                last = lib;
            } else {
                last = first = lib;
                lib->prev = lib->next = NULL;
            }
        }
    }

    return first;
}

static int dlr_lmid_from_handle(void *handle, Lmid_t *id)
{
    if (dlinfo(handle, RTLD_DI_LMID, id) != 0) {
        errno = ENOSYS;
        dlr_debug(1, "dlinfo() failed on handle 0x%lx: %s", handle, dlerror());
        return -1;
    }
    return 1;
}

/* Library map sorting implementation */
typedef struct {
    dlr_library_t* el;
} dlr_library_array_t;

static int dlr_libraries_compar_by_libname(const dlr_library_array_t *a, const dlr_library_array_t *b)
{
    int r;
    r = memcmp(a->el->libname, b->el->libname,
            (a->el->libname_l < b->el->libname_l) ? a->el->libname_l : b->el->libname_l);
    return (r != 0) ? r : a->el->libname_l - b->el->libname_l;
}

static dlr_library_t* dlr_sort_libraries_by_libname(dlr_library_t *libs)
{
    size_t c, i;
    dlr_library_t *lib;
    dlr_library_array_t *array;

    c = dlr_count_libraries(libs);

    /* Construct sequential array needed for qsort */
    array = (dlr_library_array_t *) malloc(sizeof(dlr_library_array_t) * c);
    for (lib = libs; lib != NULL; lib = lib->next) {
        array->el = lib;
        array++;
    }
    array -= c;

    /* Use system qsort() for sorting */
    qsort(array, c, sizeof(dlr_library_array_t),
            (int (*)(const void*, const void*))dlr_libraries_compar_by_libname);

    /* Finally, reset pointers in the double-linked list */
    array[0].el->prev = NULL;
    for (i = 1; i < c; i++) {
        array[i].el->prev = array[i - 1].el;
        array[i-1].el->next = array[i].el;
    }
    array[c-1].el->next = NULL;
    lib = array[0].el; /* first one */
    free(array);

    return lib;
}

static char* skip_spaces(char *s)
{
    for (;*s != '\0' && isspace(*s); s++);
    return s;
}

#define DLR_DEBUG_LIBCOMPAT(action, msg, ...) \
    dlr_debug(1, "%s (%.*s vs. %.*s): " msg, action, \
            (int) base->soname_l, base->soname, \
            (int) against->soname_l, against->soname, \
            __VA_ARGS__)
#define DLR_ERROR_LIBCOMPAT(msg, ...) \
    dlr_set_error("%.*s vs. %.*s: " msg, \
            (int) base->soname_l, base->soname, \
            (int) against->soname_l, against->soname, \
            __VA_ARGS__);

static int dlr_are_libraries_compatible(dlr_library_t *base, dlr_library_t *against, dlr_symbol_t *symbol)
{
    unsigned int l;
    char exp[MAX_DLR_EXPRESSION_LENGTH+1];

    int is_compat;
    char *tok;
    unsigned char tok_compat;

    if (symbol == NULL) {
        DLR_DEBUG_LIBCOMPAT("ACCEPT", "no restrictions symbol (%s) present",
                dlr_get_symbol_name());
        return 1;
    }

    /* Verify magic */
    if (strncmp(symbol->magic, DLR_SYMBOL_MAGIC, sizeof(symbol->magic))) {
        DLR_DEBUG_LIBCOMPAT("ACCEPT", "restrictions symbol (%s) magic (%.*s) unrecognized",
                dlr_get_symbol_name(), (int)sizeof(DLR_SYMBOL_MAGIC)-1, symbol->magic);
        return 1;
    }

    l = symbol->expression_length;
    if (l > MAX_DLR_EXPRESSION_LENGTH) {
        DLR_ERROR_LIBCOMPAT("restrictions symbol expression is too long (%u). Maximum is %u",
                l, MAX_DLR_EXPRESSION_LENGTH);
        return -1;
    }

    if (l == 0 || symbol->expression == NULL) {
        DLR_DEBUG_LIBCOMPAT("ACCEPT", "restrictions symbol expression is empty (l=%d,exp=%lx)",
                l, symbol->expression);
        return 1;
    }

    strncpy(exp, symbol->expression, l);
    exp[l] = '\0';

    /* Libraries are compatible unless told otherwise */
    is_compat = 1;
    tok = strtok(exp, ",");
    while (tok != NULL) {
        /* Parse token */
        tok = skip_spaces(tok);

        if (strncmp(tok, "ACCEPT:", 7) == 0) {
            tok_compat = 1;
            tok += 7;
        } else if (strncmp(tok, "REJECT:", 7) == 0) {
            tok_compat = 0;
            tok += 7;
        } else {
            errno = EINVAL;
            dlr_set_error("%.*s vs. %.*s: syntax error in restriction expression (%s):%d: ACCEPT: or REJECT: expected",
                    (int) base->soname_l, base->soname, (int) against->soname_l, against->soname,
                    exp, (int)(tok - exp + 1));
            return -1;
        }

        tok = skip_spaces(tok);

        /* Special expressions (the only supported right now) */
        if (strcmp(tok, "OTHERSOVERSION") == 0) {
            if (!(base->soversion_l == against->soversion_l &&
                strncmp(base->soversion, against->soversion, against->soversion_l) == 0))
            {
                is_compat = tok_compat;
            }
        } else {
            errno = ENOTSUP;
            dlr_set_error("%.*s vs. %.*s: unsupported token in restriction expression (%s):%d: %s",
                    (int) base->soname_l, base->soname, (int) against->soname_l, against->soname,
                    exp, (int)(tok - exp + 1), tok);
            return -1;
        }

        tok = strtok(NULL, ",");
    }

    DLR_DEBUG_LIBCOMPAT(((is_compat) ? "ACCEPT" : "REJECT"),
            "restriction expression (%s) processed", exp);

    if (is_compat == 0) {
        DLR_ERROR_LIBCOMPAT("libraries conflict%s", "");
    }

    return is_compat;
}

int dlr_are_symbol_objects_compatible(void *h_base, void *h_against)
{
    dlr_library_t *libs_base, *libs_against;
    dlr_library_t *base, *against;
    dlr_symbol_t *symbol;
    void *h_cand;
    Lmid_t lmid_against;
    int status;

    dlr_debug(2, "Entering dlr_are_symbol_objects_compatible() ...");

    /* Create dlr_library structures for libraries in the link map */
    dlr_debug(2, "Loading link map of the base (typically global) symbol object ...");
    errno = 0;
    libs_base = dlr_libraries_from_handle(h_base);
    if (libs_base == NULL && errno != 0) {
        return -1;
    }

    dlr_debug(2, "Loading link map of the external (typically a library being dlopen()'ed) symbol object ...");
    errno = 0;
    libs_against = dlr_libraries_from_handle(h_against);
    if (libs_against == NULL && errno != 0) {
        dlr_free_libraries(libs_base);
        return -1;
    }
    if (dlr_lmid_from_handle(h_against, &lmid_against) < 0) {
        dlr_free_libraries(libs_base);
        dlr_free_libraries(libs_against);
        return -1;
    }

    /* Sort libraries (FIXME: simple nested "foreach" loops might be faster) */
    libs_base = dlr_sort_libraries_by_libname(libs_base);
    libs_against = dlr_sort_libraries_by_libname(libs_against);

    /* Compare by library name. Matches are candidates for restrictions */
    errno = 0;
    against = libs_against;
    status = 1; /* ACCEPT by default */
    for (base = libs_base; base != NULL && status > 0; base = base->next) {
        /* Move cursor to the closest match against base libname */
        int r;
        while (against != NULL &&
               (r = strncmp(against->libname, base->libname, against->libname_l)) < 0)
        {
            against = against->next;
        }
        if (against == NULL) {
            break; /* Done */
        }
        /* If library names match, check if full paths are the same (i.e. the same lib) */
        if (r == 0 && base->libname_l == against->libname_l &&
            strcmp(base->link_map->l_name, against->link_map->l_name) != 0)
        {
            /* Candidate for restrictions. Verify further */
            h_cand = dlmopen(lmid_against, against->link_map->l_name, RTLD_LAZY | RTLD_LOCAL);
            if (h_cand == NULL) {
                dlr_set_error("unable to open %s for restrictions symbol retrieval",
                        against->link_map->l_name);
                status = -1;
                break;
            }
            symbol = (dlr_symbol_t*) dlsym(h_cand, dlr_get_symbol_name());
            dlerror(); /* clear dlerror state */
            status = dlr_are_libraries_compatible(base, against, symbol);
            dlclose(h_cand);
        }
    }

    dlr_free_libraries(libs_base);
    dlr_free_libraries(libs_against);

    return status;
}

/* An extended wrapper around dlopen() with runtime restriction checking */
void* dlr_dlopen_extended(const char *file, int mode, int print_error, int fail_on_error)
{
    void *h_global, *h_file;
    int status;

    errno = 0;
    h_file = dlmopen(LM_ID_NEWLM, file, RTLD_LAZY | RTLD_LOCAL);
    if (h_file == NULL) {
        return NULL;
    }

    h_global = dlopen(0, RTLD_LAZY | RTLD_LOCAL);
    if (h_global == NULL) {
        dlr_set_error("unable to dlopen() global symbol object");
        if (print_error) {
            dlr_print_pretty_error(file);
        }
        if (fail_on_error) {
            dlclose(h_file);
            return NULL;
        }
    }

    if (h_global != NULL) {
        status = dlr_are_symbol_objects_compatible(h_global, h_file);
        if (status < 0 && print_error) {
            dlr_print_pretty_error(file);
        }
        /* Check for failure */
        if (status == 0 || (status < 0 && fail_on_error)) {
            if (status == 0 && print_error) {
                dlr_print_pretty_error(file);
            }
            dlclose(h_file);
            h_file = NULL;
        }
    }

    if (h_global != NULL)
        dlclose(h_global);

    if (h_file != NULL) {
        /* Reopen the file with base link map */
        dlclose(h_file);
        h_file = dlopen(file, mode);
    }

    return h_file;
}