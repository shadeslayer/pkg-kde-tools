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
# HACK. I could not think of anything less hardcoded to replace it.
# It is temporal anyway.
ifndef THIS_SHOULD_GO_TO_UNSTABLE
	@echo "Unstable uploads should be allowed explicitly (set THIS_SHOULD_GO_TO_UNSTABLE)" && /bin/false >&2
endif

.PHONY: upstream_version_check
