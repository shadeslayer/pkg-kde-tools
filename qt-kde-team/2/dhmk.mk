# Copyright (C) 2011 Modestas Vainius <modax@debian.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

# Load command sequences: $(target)_commands variables
include $(dir $(lastword $(MAKEFILE_LIST)))/commands.mk

dhmk_top_makefile = $(firstword $(MAKEFILE_LIST))
dhmk_stamped_targets = configure build
dhmk_dynamic_targets = install binary-indep binary-arch binary clean
dhmk_standard_targets = $(dhmk_stamped_targets) $(dhmk_dynamic_targets)
dhmk_all_commands = $(strip $(foreach t,$(standard_targets),$($(t)_commands)))

dhmk_overrides_mk = debian/dhmk_command_overrides.mk
dhmk_calc_overrides_magic = \#\#dhmk_calc_overrides\#\#

ifeq ($(dhmk_calc_overrides),yes)

# Handle override calculation

override_%: FORCE
	$(dhmk_calc_overrides_magic) dhmk_$@ = no

# NOTE: implicit targets do not work as expected when grouped together. The
# following workaround is needed to generate a separate rule for each target.
define dhmk_t_override_code
$(eval $(t)_override_%: FORCE
	$(CALC_OVERRIDES_MAGIC) dhmk_$$@ = no
)
endef
$(foreach t,$(dhmk_standard_targets),$(dhmk_t_override))

calc_overrides: $(foreach cmd,$(dhmk_all_commands),override_$(cmd))
calc_overrides: $(foreach t,$(dhmk_standard_targets),\
    $(foreach cmd,$(strip $($(t)_commands)),$(t)_override_$(cmd)))
.PHONY: calc_overrides
else

# Run override calculation and include a generated file

$(dhmk_overrides_mk): $(MAKEFILE_LIST)
	$(MAKE) -f $(dhmk_top_makefile) -j1 -n --no-print-directory \
        calc_overrides dhmk_calc_overrides=yes 2>&1 | \
        sed -n '/^$(dhmk_calc_overrides_magic)[[:space:]]\+/ \
        { s/^$(dhmk_calc_overrides_magic)[[:space:]]\+//; p }' > $@

-include $(dhmk_overrides_mk)

endif

dhmk_get_override = $(if $(dhmk_$(1)),,$(MAKE) -f $(dhmk_top_makefile) $(1))
# Empty line before endef is necessary
define dhmk_run_command
$(or $(call dhmk_get_override,$(1)_override_$(2)),\
     $(call dhmk_get_override,override_$(2)),\
     $(2)\
)

endef

# Generate command chains for the standard targets
$(foreach t,$(dhmk_standard_targets),debian/dhmk_$(t)): debian/dhmk_%:
	$(foreach cmd,$(strip $($*_commands)),\
		$(call dhmk_run_command,$*,$(cmd)) $(dhmk_target_dh_options))
	$(if $(filter $*,$(dhmk_stamped_targets)),touch $@)
	# "$*" is done

# Mark dynamic targets as phony
.PHONY: $(foreach t,$(dhmk_dynamic_targets),debian/dhmk_$(t))

# Relationships between targets + common options
# NOTE: do not use standard targets here directly, use their debian/dhmk_target
# counterparts.
debian/dhmk_build: debian/dhmk_configure
debian/dhmk_install: debian/dhmk_build
debian/dhmk_binary: debian/dhmk_install
debian/dhmk_binary-arch: debian/dhmk_install
debian/dhmk_binary-arch: dhmk_target_dh_options = -a
debian/dhmk_binary-indep: debian/dhmk_install
debian/dhmk_binary-indep: dhmk_target_dh_options = -i

# Implicitly delegate other targets to debian/dhmk_% ones. Hence the top
# targets (build, configure, install ...) are still cancellable.
%: debian/dhmk_%
	echo "$@ action has been successfully completed."

.PHONY: FORCE
