# policy.mk must be included from debian_qt_kde.mk
ifdef dqk_dir

dqk_disable_policy_check ?=
dqk_distribution := $(shell dpkg-parsechangelog | sed -n '/^Distribution:/{ s/^Distribution:[[:space:]]*//g; p; q }')
dqk_kde_major_version := $(shell echo "$(dqk_upstream_version)" | cut -d. -f1-2)
dqk_maintainer_check := $(shell grep -e '^Maintainer:.*<debian-qt-kde@lists\.debian\.org>[[:space:]]*$$' \
                                     -e '^XSBC-Original-Maintainer:.*<debian-qt-kde@lists\.debian\.org>[[:space:]]*$$' debian/control)

# Distribution-specific policy file may not exist. It is fine
ifeq (,$(filter $(dqk_distribution),$(dqk_disable_policy_check)))
    dqk_distribution_policy = $(dqk_dir)/policy/$(dqk_distribution).mk
    ifeq (yes,$(shell test -f "$(dqk_distribution_policy)" && echo yes))
        include $(dqk_dir)policy/$(dqk_distribution).mk
    endif
endif

# Reject packages not maintained by Debian Qt/KDE Maintainers
ifeq (,$(dqk_maintainer_check))
    $(info ### debian_qt_kde.mk can only be used with packages (originally) maintained by)
    $(info ### Debian Qt/KDE Maintainers, please read /usr/share/pkg-kde-tools/qt-kde-team/README)
    $(info ### for more details. Please read /usr/share/doc/pkg-kde-tools/README.Debian for more)
    $(info ### information on how to use pkg-kde-tools with other KDE packages.)
    $(error debian_qt_kde.mk usage denied by policy.)
endif

endif
