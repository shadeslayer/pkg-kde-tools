ifndef dqk_dir

dqk_dir := $(dir $(lastword $(MAKEFILE_LIST)))

# Include dhmk file
include $(dqk_dir)dhmk.mk

# For performance reasons skip the rest in the override info mode. The slowdown
# is mostly caused by $(shell) functions (e.g. dpkg-parsechangelog).
ifneq ($(dhmk_override_info_mode),yes)

dqk_sourcepkg := $(shell dpkg-parsechangelog | sed -n '/^Source:/{ s/^Source:[[:space:]]*//; p; q }')
dqk_upstream_version ?= $(shell dpkg-parsechangelog | sed -n '/^Version:/{ s/^Version:[[:space:]]*\(.*\)-.*/\1/g; p; q }')
dqk_destdir = $(CURDIR)/debian/tmp

# We want to use kde and pkgkde-symbolshelper plugins by default
dh := --with=kf5,pkgkde-symbolshelper $(dh)

# dqk_disable_policy_check lists distributions for which policy check should be
# disabled
dqk_disable_policy_check ?=
include $(dqk_dir)policy.mk

# Support list-missing target
include $(dqk_dir)list-missing.mk

# Support lintian target
include $(dqk_dir)lintian.mk

# KDE packages are parallel safe. Add --parallel to dh_auto_% commands
$(call set_command_options,dh_auto_%, += --parallel)

# Use xz compression by default
$(call set_command_options,dh_builddeb, += -u-Zxz)

# Link with --as-needed by default
# (subject to be moved to kde dh addon/debhelper buildsystem)
dqk_link_with_as_needed ?= yes
ifneq (,$(findstring yes, $(dqk_link_with_as_needed)))
    dqk_link_with_as_needed := no
    ifeq (,$(findstring no-as-needed, $(DEB_BUILD_OPTIONS)))
        dqk_link_with_as_needed := yes
        export LDFLAGS += -Wl,--as-needed
    endif
endif

# Set the link_with_no_undefined=no in order to disable linking with
# --no-undefined (default value is inherited from $(dqk_link_with_as_needed))
dqk_link_with_no_undefined ?= $(dqk_link_with_as_needed)
ifneq (,$(findstring yes, $(dqk_link_with_no_undefined)))
    dqk_link_with_no_undefined := no
    ifeq (,$(findstring no-no-undefined, $(DEB_BUILD_OPTIONS)))
        dqk_link_with_no_undefined := yes
        export LDFLAGS += -Wl,--no-undefined
    endif
endif

# Run dh_sameversiondep
run_dh_sameversiondep:
	dh_sameversiondep
$(foreach t,$(dhmk_binary_targets),pre_$(t)_dh_gencontrol): run_dh_sameversiondep

debian/stamp-man-pages:
	if ! test -d debian/man/out; then mkdir -p debian/man/out; fi
	for f in $$(find debian/man -name '*.sgml'); do \
		docbook-to-man $$f > debian/man/out/`basename $$f .sgml`.1; \
	done
	for f in $$(find debian/man -name '*.man'); do \
		soelim -I debian/man $$f \
		> debian/man/out/`basename $$f .man`.`head -n1 $$f | awk '{print $$NF}'`; \
	done
	touch debian/stamp-man-pages
$(foreach t,build-arch build-indep build,post_$(t)_dh_auto_build): debian/stamp-man-pages

cleanup_manpages:
	rm -rf debian/man/out
	-rmdir debian/man
	rm -f debian/stamp-man-pages
post_clean: cleanup_manpages

# Install files to $(dqk_sourcepkg)-doc-html package if needed
dqk_doc-html_dir = $(CURDIR)/debian/$(dqk_sourcepkg)-doc-html
install_to_doc-html_package:
	set -e; \
	if [ -d "$(dqk_doc-html_dir)" ]; then \
	    for doc in `cd $(dqk_destdir)/usr/share/doc/kde/HTML/en; find . -name index.docbook`; do \
	        pkg=$${doc%/index.docbook}; pkg=$${pkg#./}; \
	        echo Building $$pkg HTML docs...; \
	        mkdir -p $(dqk_doc-html_dir)/usr/share/doc/kde/HTML/en/$$pkg; \
	        cd $(dqk_doc-html_dir)/usr/share/doc/kde/HTML/en/$$pkg; \
	        meinproc5 $(dqk_destdir)/usr/share/doc/kde/HTML/en/$$pkg/index.docbook; \
	    done; \
	    for pkg in $(DOC_HTML_PRUNE) ; do \
	        rm -rf $(dqk_doc-html_dir)/usr/share/doc/kde/HTML/en/$$pkg; \
	    done; \
	fi
$(foreach t,install-indep install,post_$(t)_dh_install): install_to_doc-html_package

post_binary: list-missing lintian

.PHONY: run_dh_sameversiondep cleanup_manpages install_to_doc-html_package

endif # ifneq ($(dhmk_override_info_mode),yes)
endif # ifndef dqk_dir
