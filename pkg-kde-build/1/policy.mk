include /usr/share/cdbs/1/rules/buildvars.mk

DEB_KDE_DISTRIBUTION := $(shell dpkg-parsechangelog | grep '^Distribution: ' | sed 's/^Distribution: \(.*\)/\1/g')
DEB_KDE_MAJOR_VERSION := $(shell echo "$(DEB_UPSTREAM_VERSION)" | cut -d. -f1-2)

# Policy file may not exist. It is fine
ifeq (,$(filter $(DEB_KDE_DISTRIBUTION),$(DEB_KDE_DISABLE_POLICY_CHECK)))
  -include /usr/share/pkg-kde-tools/pkg-kde-build/1/policy/$(DEB_KDE_DISTRIBUTION).mk
endif
