ifndef _cdbs_debian_qt_kde
_cdbs_debian_qt_kde = 1

include /usr/share/cdbs/1/class/cmake.mk
include /usr/share/cdbs/1/rules/debhelper.mk
include /usr/share/cdbs/1/rules/utils.mk

# If quilt is in Build-Depends, enable quilt patch system support
# for 1.0 format.
ifneq ($(shell sed -n '/^Build-Depends: / { : lookforquilt { /\bquilt\b/ { p; b; }; n; /^[[:space:]]\+/ { b lookforquilt };  } }' debian/control),)
    include /usr/share/cdbs/1/rules/patchsys-quilt.mk
endif

DEB_PKG_KDE_DATA := /usr/share/pkg-kde-tools
DEB_PKG_KDE_MAKEFILES := $(DEB_PKG_KDE_DATA)/makefiles/1
DEB_PKG_KDE_QT_KDE_TEAM := $(DEB_PKG_KDE_DATA)/qt-kde-team/1

# DEB_KDE_DISABLE_POLICY_CHECK lists distributions for which
# policy check should be disabled
DEB_KDE_DISABLE_POLICY_CHECK ?=
include $(DEB_PKG_KDE_QT_KDE_TEAM)/policy.mk

# Link with --as-needed by default
DEB_KDE_LINK_WITH_AS_NEEDED ?= yes

# Our packages are parallel safe
DEB_BUILD_PARALLEL = yes

# Readd old (<< 0.11.1) flags from the kde4_flags here. Absolute majority of
# those are kde4libs specific but add them anyway in order to avoid accidental
# breakage in the old packaging (esp. kde4libs).
DEB_CMAKE_KDE4_FLAGS += \
    -DKDE4_BUILD_TESTS=false \
    -DKDE_DISTRIBUTION_TEXT="Kubuntu packages" \
    -DCMAKE_SKIP_RPATH:BOOL=OFF \
    -DKDE4_USE_ALWAYS_FULL_RPATH=false \
    -DCONFIG_INSTALL_DIR=/usr/share/kde4/config \
    -DDATA_INSTALL_DIR=/usr/share/kde4/apps \
    -DHTML_INSTALL_DIR=/usr/share/doc/kde/HTML \
    -DKCFG_INSTALL_DIR=/usr/share/kde4/config.kcfg \
    -DLIB_INSTALL_DIR=/usr/lib \
    -DSYSCONF_INSTALL_DIR=/etc \
    -DLIBKDEINIT_INSTALL_DIR:PATH=/usr/lib/kde4/libkdeinit

# Include default KDE 4 cmake configuration variables
include $(DEB_PKG_KDE_MAKEFILES)/variables.mk

# Add support for pkgkde-symbolshelper by default
include $(DEB_PKG_KDE_MAKEFILES)/cdbs/symbolshelper.mk

# Since cmake 2.6.2 or higher is required from now on, enable
# relative paths to get more ccache hits.
# NOTE: might not work with vanilla 2.6.2, only with Debian's one.
DEB_CMAKE_KDE4_FLAGS += -DCMAKE_USE_RELATIVE_PATHS=ON

# Pass standard KDE 4 flags to cmake via appropriate CDBS variable
# (DEB_CMAKE_EXTRA_FLAGS)
DEB_CMAKE_EXTRA_FLAGS += $(DEB_CMAKE_KDE4_FLAGS) $(DEB_CMAKE_CUSTOM_FLAGS)

DEB_COMPRESS_EXCLUDE = .dcl .docbook -license .tag .sty .el

#DEB_MAKE_ENVVARS += XDG_CONFIG_DIRS=/etc/xdg XDG_DATA_DIRS=/usr/share
#DEB_STRIP_EXCLUDE = so

DEB_DH_MAKESHLIBS_ARGS += -Xusr/lib/kde4/

common-build-arch:: debian/stamp-man-pages
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

clean::
	rm -rf debian/man/out
	-rmdir debian/man
	rm -f debian/stamp-man-pages
	rm -f CMakeCache.txt


$(patsubst %,binary-install/%,$(DEB_PACKAGES)) :: binary-install/%:
	$(if $(wildcard /usr/bin/dh_bugfiles),dh_bugfiles -p$(cdbs_curpkg) $(DEB_DH_BUGFILES_ARGS))

$(patsubst %,binary-post-install/%,$(DEB_ARCH_PACKAGES)) :: binary-post-install/%:
	dh_movelibkdeinit -p$(cdbs_curpkg) $(DEB_DH_MOVELIBKDEINIT_ARGS)

binary-install/$(DEB_SOURCE_PACKAGE)-doc-html::
	set -e; \
	for doc in `cd $(DEB_DESTDIR)/usr/share/doc/kde/HTML/en; find . -name index.docbook`; do \
		pkg=$${doc%/index.docbook}; pkg=$${pkg#./}; \
		echo Building $$pkg HTML docs...; \
		mkdir -p $(CURDIR)/debian/$(DEB_SOURCE_PACKAGE)-doc-html/usr/share/doc/kde/HTML/en/$$pkg; \
		cd $(CURDIR)/debian/$(DEB_SOURCE_PACKAGE)-doc-html/usr/share/doc/kde/HTML/en/$$pkg; \
		meinproc4 $(DEB_DESTDIR)/usr/share/doc/kde/HTML/en/$$pkg/index.docbook; \
	done
	for pkg in $(DOC_HTML_PRUNE) ; do \
		rm -rf debian/$(DEB_SOURCE_PACKAGE)-doc-html/usr/share/doc/kde/HTML/en/$$pkg; \
	done

# Run dh_sameversiondep
common-binary-predeb-arch common-binary-predeb-indep::
	dh_sameversiondep $(if $(filter common-binary-predeb-arch,$@),-a,-i)

# _cdbs_debian_qt_kde
endif
