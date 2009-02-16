upstream_version_check:
ifeq (srcpkg_ok,$(patsubst kde%,srcpkg_ok,$(DEB_SOURCE_PACKAGE)))
ifeq (version_ok,$(patsubst 4:4.%,version_ok,$(DEB_VERSION)))
	@\
  if dpkg --compare-versions "$(DEB_KDE_MAJOR_VERSION).60" le "$(DEB_UPSTREAM_VERSION)" && \
     dpkg --compare-versions "$(DEB_UPSTREAM_VERSION)" lt "$(DEB_KDE_MAJOR_VERSION).90"; then \
          echo >&2; \
          echo "    ###" >&2; \
          echo "    ### CAUTION: early KDE development releases (alpha or beta) ($(DEB_UPSTREAM_VERSION))" >&2; \
          echo "    ###          should not be uploaded to unstable" >&2; \
          echo "    ###" >&2; \
          echo >&2; \
  fi
endif
endif

binary-indep binary-arch: upstream_version_check

pre-build clean:: upstream_version_check

.PHONY: upstream_version_check
