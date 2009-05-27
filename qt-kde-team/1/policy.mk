# policy.mk must be included from debian_qt_kde.mk
ifdef _cdbs_debian_qt_kde

include /usr/share/cdbs/1/rules/buildvars.mk

DEB_KDE_DISTRIBUTION := $(shell dpkg-parsechangelog | grep '^Distribution: ' | sed 's/^Distribution: \(.*\)/\1/g')
DEB_KDE_MAJOR_VERSION := $(shell echo "$(DEB_UPSTREAM_VERSION)" | cut -d. -f1-2)
DEB_KDE_MAINTAINER_CHECK := $(shell grep -e '^Maintainer:.*<debian-qt-kde@lists\.debian\.org>[[:space:]]*$$' \
                                         -e '^XSBC-Original-Maintainer:.*<debian-qt-kde@lists\.debian\.org>[[:space:]]*$$' debian/control)

# Distribution-specific policy file may not exist. It is fine
ifeq (,$(filter $(DEB_KDE_DISTRIBUTION),$(DEB_KDE_DISABLE_POLICY_CHECK)))
  -include $(DEB_PKG_KDE_QT_KDE_TEAM)/policy/$(DEB_KDE_DISTRIBUTION).mk
endif

# Reject packages not maintained by Debian Qt/KDE Maintainers
ifeq (,$(DEB_KDE_MAINTAINER_CHECK))
$(info ### debian_qt_kde.mk can only be used with packages (originally) maintained by)
$(info ### Debian Qt/KDE Maintainers, please read /usr/share/pkg-kde-tools/qt-kde-team/README)
$(info ### for more details. Please read /usr/share/doc/pkg-kde-tools/README.Debian for more)
$(info ### information on how to use pkg-kde-tools with other KDE packages.)
$(error debian_qt_kde.mk usage denied by policy.)
endif

endif
