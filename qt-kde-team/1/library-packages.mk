_BINARYVERSION := $(shell dpkg-parsechangelog | grep '^Version: ' | sed 's/^Version: //')

# All library packages
DEB_LIBRARY_PACKAGES := $(filter-out %-dev,$(filter lib%,$(DEB_ARCH_PACKAGES)))
ifneq (,$(DEB_ALL_LIBRARIES_SUBST_PACKAGES))

DEB_ALL_LIBRARIES_SUBST := $(foreach pkg,$(DEB_LIBRARY_PACKAGES),$(patsubst %,% (= $(_BINARYVERSION)),,$(pkg)))

$(patsubst %,binary-predeb/%,$(DEB_ALL_LIBRARIES_SUBST_PACKAGES)):: binary-predeb/%:
	test -f debian/$(cdbs_curpkg).substvars || touch debian/$(cdbs_curpkg).substvars
	echo 'allLibraries=$(DEB_ALL_LIBRARIES_SUBST)' >> debian/$(cdbs_curpkg).substvars

endif

# KDE 4.3 library packages
ifneq (,$(DEB_KDE43_LIBRARY_PACKAGES))
ifneq (,$(DEB_KDE43_LIBRARIES_SUBST_PACKAGES))
DEB_KDE43_LIBRARIES_SUBST := $(foreach pkg,$(DEB_KDE43_LIBRARY_PACKAGES),$(patsubst %,% (= $(_BINARYVERSION)),,$(pkg)))

$(patsubst %,binary-predeb/%,$(DEB_KDE43_LIBRARIES_SUBST_PACKAGES)):: binary-predeb/%:
	test -f debian/$(cdbs_curpkg).substvars || touch debian/$(cdbs_curpkg).substvars
	echo 'kde43Libraries=$(DEB_KDE43_LIBRARIES_SUBST)' >> debian/$(cdbs_curpkg).substvars
endif
endif


# Generate shlibs local files if requested
ifneq (,$(DEB_STRICT_LOCAL_SHLIBS_PACKAGES))
$(patsubst %,binary-fixup/%,$(DEB_STRICT_LOCAL_SHLIBS_PACKAGES)) :: binary-fixup/%: binary-strip/%
	if test -e debian/$(cdbs_curpkg)/DEBIAN/shlibs ; then \
		sed 's/>=[^)]*/= $(_BINARYVERSION)/' debian/$(cdbs_curpkg)/DEBIAN/shlibs >> debian/shlibs.local ;\
	fi

clean::
	rm -f debian/shlibs.local

endif
