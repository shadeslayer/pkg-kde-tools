include /usr/share/cdbs/1/rules/buildvars.mk

SYMBOLSHELPER_PACKAGES := $(filter $(DEB_PACKAGES),$(patsubst debian/%.symbols.in,%,$(wildcard debian/*.symbols.in)))

$(patsubst %,binary-strip/%,$(SYMBOLSHELPER_PACKAGES)):: binary-strip/%:
	pkgkde-symbolshelper symbolfile -p $(cdbs_curpkg) -o debian/$(cdbs_curpkg).symbols.$(DEB_HOST_ARCH)

$(patsubst %,binary-fixup/%,$(SYMBOLSHELPER_PACKAGES)):: binary-fixup/%:
	pkgkde-symbolshelper postgensymbols -p $(cdbs_curpkg) -v

clean::
	rm -f $(patsubst %,debian/%.symbols.$(DEB_HOST_ARCH),$(SYMBOLSHELPER_PACKAGES))
