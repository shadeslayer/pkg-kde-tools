ifndef dqk_dir

dqk_dir := $(dir $(lastword $(MAKEFILE_LIST)))
dqk_sourcepkg := $(shell dpkg-parsechangelog | sed -n '/^Source:/{ s/^Source:[[:space:]]*//; p; q }')
dqk_destdir = $(CURDIR)/debian/tmp

# We want to use kde and pkgkde-symbolshelper plugins by default
# Moreover, KDE packages are parallel safe
dh := --with=kde,pkgkde-symbolshelper --parallel $(dh)

# Include dhmk file
include $(dqk_dir)dhmk.mk

# TODO:
# DEB_KDE_DISABLE_POLICY_CHECK lists distributions for which
# policy check should be disabled
# DEB_KDE_DISABLE_POLICY_CHECK ?=
# include $(DEB_PKG_KDE_QT_KDE_TEAM)/policy.mk

# TODO:
# Link with --as-needed by default
# DEB_KDE_LINK_WITH_AS_NEEDED ?= yes

# Since cmake 2.6.2 or higher is required from now on, enable relative paths to
# get more ccache hits.
configure_dh_auto_configure += "-u-DCMAKE_USE_RELATIVE_PATHS=ON"

# Run dh_sameversiondep
run_dh_sameversiondep:
	dh_sameversiondep
$(foreach t,$(dhmk_install_targets),post_$(t)_dh_shlibdeps): run_dh_sameversiondep

endif # ifndef dqk_dir
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
$(foreach t,binary-arch binary,post_$(t)_dh_auto_build): debian/stamp-man-pages

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
	        meinproc4 $(dqk_destdir)/usr/share/doc/kde/HTML/en/$$pkg/index.docbook; \
	    done; \
	    for pkg in $(DOC_HTML_PRUNE) ; do \
	        rm -rf $(dqk_doc-html_dir)/usr/share/doc/kde/HTML/en/$$pkg; \
	    done; \
	fi
$(foreach t,install-indep install,post_$(t)_dh_install): install_to_doc-html_package

.PHONY: run_dh_sameversiondep cleanup_manpages install_to_doc-html_package
