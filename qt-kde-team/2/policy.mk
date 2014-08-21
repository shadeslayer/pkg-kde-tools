# policy.mk must be included from debian_qt_kde.mk
ifdef dqk_dir

dqk_disable_policy_check ?=
dqk_distribution := $(shell dpkg-parsechangelog | sed -n '/^Distribution:/{ s/^Distribution:[[:space:]]*//g; p; q }')
dqk_kde_major_version := $(shell echo "$(dqk_upstream_version)" | cut -d. -f1-2)

# Distribution-specific policy file may not exist. It is fine
ifeq (,$(filter $(dqk_distribution),$(dqk_disable_policy_check)))
    dqk_distribution_policy = $(dqk_dir)/policy/$(dqk_distribution).mk
    ifeq (yes,$(shell test -f "$(dqk_distribution_policy)" && echo yes))
        include $(dqk_dir)policy/$(dqk_distribution).mk
    endif
endif

endif
