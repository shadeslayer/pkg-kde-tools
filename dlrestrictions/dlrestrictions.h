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

#ifndef DLR_LIBRARY_NAME
#define DLR_LIBRARY_NAME            "DLRestrictions"
#endif

#define DLR_STRINGIFY(s)            #s
#define DLR_STRINGIFY2(s)           DLR_STRINGIFY(s)

#define DLR_SYMBOL                  debian_dlrestrictions
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

void dlr_set_symbol_name(const char *name);
const char* dlr_get_symbol_name(void);
const char* dlr_extended_error(void);

int dlr_are_symbol_objects_compatible(void *h_base, void *h_against);
void* dlr_dlopen_extended(const char *file, int mode, int print_error, int fail_on_error);

#endif
