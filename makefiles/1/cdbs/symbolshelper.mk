include /usr/share/cdbs/1/rules/buildvars.mk

ifndef _cdbs_pkgkde_symbolshelper
_cdbs_pkgkde_symbolshelper = 1

ifneq (/usr/share/pkg-kde-tools/bin,$(filter /usr/share/pkg-kde-tools/bin,$(subst :, ,$(PATH))))
    export PATH := /usr/share/pkg-kde-tools/bin:$(PATH)
endif

SYMBOLSHELPER_PACKAGES := $(filter $(DEB_PACKAGES),$(patsubst debian/%.symbols.in,%,$(wildcard debian/*.symbols.in)))

ifneq (,$(strip $(SYMBOLSHELPER_PACKAGES)))

$(patsubst %,binary-strip/%,$(SYMBOLSHELPER_PACKAGES)):: binary-strip/%:
	pkgkde-symbolshelper symbolfile -p $(cdbs_curpkg) -o debian/$(cdbs_curpkg).symbols.$(DEB_HOST_ARCH)

clean::
	rm -f $(patsubst %,debian/%.symbols.$(DEB_HOST_ARCH),$(SYMBOLSHELPER_PACKAGES))

endif

endif
