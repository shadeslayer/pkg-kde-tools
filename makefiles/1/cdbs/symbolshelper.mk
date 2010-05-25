include /usr/share/cdbs/1/rules/buildvars.mk

ifndef _cdbs_pkgkde_symbolshelper
_cdbs_pkgkde_symbolshelper = 1

ifneq (/usr/share/pkg-kde-tools/bin,$(filter /usr/share/pkg-kde-tools/bin,$(subst :, ,$(PATH))))
    export PATH := /usr/share/pkg-kde-tools/bin:$(PATH)
endif

endif
