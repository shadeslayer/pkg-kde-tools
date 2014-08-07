dqk_upstream_version_check:
ifeq (srcpkg_ok,$(patsubst kde%,srcpkg_ok,$(dqk_sourcepkg)))
ifeq (version_ok,$(patsubst 4:4.%,version_ok,$(dqk_upstream_version)))
	@\
  if dpkg --compare-versions "$(dqk_kde_major_version).60" le "$(dqk_upstream_version)" && \
     dpkg --compare-versions "$(dqk_upstream_version)" lt "$(dqk_kde_major_version).90"; then \
          echo >&2; \
          echo "    ###" >&2; \
          echo "    ### CAUTION: early KDE development releases (alpha or beta) ($(dqk_upstream_version))" >&2; \
          echo "    ###          should not be uploaded to unstable" >&2; \
          echo "    ###" >&2; \
          echo >&2; \
  fi
endif
endif

$(foreach t,$(dhmk_standard_targets),pre_$(t)): dqk_upstream_version_check

.PHONY: dqk_upstream_version_check
