libpkgs_binver := $(shell dpkg-parsechangelog | grep '^Version: ' | sed 's/^Version: //')
libpkgs_arch_pkgs := $(shell dh_listpackages -a)
libpkgs_subst_hooks := $(foreach t,binary-arch binary,pre_$(t)_dh_gencontrol)

# All library packages
libpkgs_all_packages := $(filter-out %-dev %-dbg, $(filter lib%,$(libpkgs_arch_pkgs)))

ifneq (,$(libpkgs_addsubst_allLibraries))

libpkgs_allLibraries_subst := $(foreach pkg,$(libpkgs_all_packages),$(patsubst %,% (= $(libpkgs_binver)),,$(pkg)))

libpkgs_addsubst_allLibraries:
	echo 'allLibraries=$(libpkgs_allLibraries_subst)' | \
		tee -a $(foreach pkg,$(libpkgs_addsubst_allLibraries),debian/$(pkg).substvars) > /dev/null

$(libpkgs_subst_hooks): libpkgs_addsubst_allLibraries
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

libpkgs_gen_strict_local_shlibs: libpkgs_re = $(subst \|_ ,\|,$(patsubst %,%\|_,$(libpkgs_gen_strict_local_shlibs)))
libpkgs_gen_strict_local_shlibs:
	set -e; \
	if [ -n "`ls debian/*.substvars 2>/dev/null`" ]; then \
	    echo "Generating strict local shlibs on packages: $(libpkgs_gen_strict_local_shlibs)"; \
	    sed -i '/^shlibs:[^=]\+=/{ s/\(^shlibs:[^=]\+=[[:space:]]*\|,[[:space:]]*\)\($(libpkgs_re)\)\([[:space:]]*([[:space:]]*[><=]\+[^)]\+)\)\?/\1\2 (= $(libpkgs_binver))/g }' debian/*.substvars; \
    fi

$(foreach t,binary-arch binary,post_$(t)_dh_shlibdeps): libpkgs_gen_strict_local_shlibs
.PHONY: libpkgs_gen_strict_local_shlibs

endif
