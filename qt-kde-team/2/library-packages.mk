libpkgs_binver := $(shell dpkg-parsechangelog | grep '^Version: ' | sed 's/^Version: //')
libpkgs_arch_pkgs := $(shell dh_listpackages -a)
libpkgs_subst_hooks := $(foreach t,binary-arch binary,pre_$(t)_dh_gencontrol)

# All library packages
libpkgs_all_packages := $(filter-out %-dev,$(filter lib%,$(libpkgs_arch_pkgs)))

ifneq (,$(libpkgs_addsubst_allLibraries))

libpkgs_allLibraries_subst := $(foreach pkg,$(libpkgs_all_packages),$(patsubst %,% (= $(libpkgs_binver)),,$(pkg)))

libpkgs_addsubst_allLibraries:
	echo 'allLibraries=$(libpkgs_allLibraries_subst)' | \
		tee -a $(foreach pkg,$(libpkgs_addsubst_allLibraries),debian/$(pkg).substvars) > /dev/null

$(libpkgs_subst_hooks): libpkgs_add_allLibraries
.PHONY: libpkgs_addsubst_allLibraries

endif

# KDE 4.3 library packages
ifneq (,$(libpkgs_kde43_packages))
ifneq (,$(libpkgs_addsubst_kde43Libraries))

libpkgs_kde43Libraries_subst := $(foreach pkg,$(libpkgs_kde43_packages),$(patsubst %,% (= $(libpkgs_binver)),,$(pkg)))

libpkgs_add_kde43Libraries:
	echo 'kde43Libraries=$(libpkgs_kde43Libraries_subst)' | \
		tee -a $(foreach pkg,$(libpkgs_addsubst_kde43Libraries),debian/$(pkg).substvars) > /dev/null

$(libpkgs_subst_hooks): libpkgs_addsubst_kde43Libraries
.PHONY: libpkgs_addsubst_kde43Libraries

endif
endif

# Generate strict local shlibs if requested
ifneq (,$(libpkgs_gen_strict_local_shlibs))

libpkgs_gen_strict_local_shlibs:
	for pkg in $(libpkgs_gen_strict_local_shlibs); do \
	    if test -e debian/$$pkg/DEBIAN/shlibs; then \
	        echo "Generating strict local shlibs for the '$$pkg' package ..."; \
		    sed 's/>=[^)]*/= $(libpkgs_binver)/' debian/$$pkg/DEBIAN/shlibs >> debian/shlibs.local; \
	    fi; \
	done

libpkgs_clean_local_shlibs:
	rm -f debian/shlibs.local

$(foreach t,binary-arch binary,post_$(t)_dh_makeshlibs): libpkgs_gen_strict_local_shlibs
post_clean: libpkgs_clean_local_shlibs
.PHONY: libpkgs_gen_strict_local_shlibs libpkgs_clean_local_shlibs

endif
