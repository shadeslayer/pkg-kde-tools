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

dhmk_top_makefile := $(firstword $(MAKEFILE_LIST))
dhmk_this_makefile := $(lastword $(MAKEFILE_LIST))
dhmk_stamped_targets = configure build
dhmk_dynamic_targets = install binary-indep binary-arch binary clean
dhmk_standard_targets = $(dhmk_stamped_targets) $(dhmk_dynamic_targets)
dhmk_rules_mk = debian/dhmk_rules.mk
dhmk_dhmk_pl := $(dir $(dhmk_this_makefile))dhmk.pl

# $(call butfirstword,TEXT,DELIMITER)
butfirstword = $(patsubst $(firstword $(subst $2, ,$1))$2%,%,$1)

# This makefile is not parallel compatible by design (e.g. command chains
# below)
.NOTPARALLEL:

# FORCE target is used in the prerequsite lists to imitiate .PHONY behaviour
.PHONY: FORCE

############ Handle override calculation ############ 
ifeq ($(dhmk_override_info_mode),yes)

# Emit magic directives for commands which are not overriden
override_%: FORCE
	##dhmk_no_override##$*

else
############ Do all sequencing ######################

# Generate and include a dhmk rules file
$(dhmk_rules_mk): $(MAKEFILE_LIST) $(dhmk_dhmk_pl)
	$(dhmk_dhmk_pl) $(dh)

# Create an out-of-date rules file if it does not exist. Avoids make warning
include $(shell test ! -f $(dhmk_rules_mk) && touch -t 197001030000 $(dhmk_rules_mk); echo $(dhmk_rules_mk))

# Routine to run a specific command ($1 should be {target}_{command})
dhmk_override_cmd = $(if $(dhmk_$1),$(MAKE) -f $(dhmk_top_makefile) $1)
dhmk_run_command = $(or $(call dhmk_override_cmd,override_$(call butfirstword,$1,_)),$($1))

# Generate dhmk_{pre,post}_{target}_{command} targets for each target+command
$(foreach t,$(dhmk_standard_targets),$(foreach c,$(dhmk_$(t)_commands),dhmk_pre_$(t)_$(c))): dhmk_pre_%:
	$(call dhmk_run_command,$*)
$(foreach t,$(dhmk_standard_targets),$(foreach c,$(dhmk_$(t)_commands),dhmk_post_$(t)_$(c))): dhmk_post_%:

# Export common options for some actions (to submake)
debian/dhmk_binary-arch: export DH_OPTIONS = -a
debian/dhmk_binary-indep: export DH_OPTIONS = -i

# Mark dynamic standard targets as PHONY
.PHONY: $(foreach t,$(dhmk_dynamic_targets),debian/dhmk_$(t))

# Create debian/dhmk_{action} targets.
# NOTE: dhmk_run_{target}_commands are defined below
$(foreach t,$(dhmk_standard_targets),debian/dhmk_$(t)): debian/dhmk_%:
	$(if $(DH_OPTIONS),#### NOTE: DH_OPTIONS is set to $(DH_OPTIONS) ####)
	$(MAKE) -f $(dhmk_top_makefile) dhmk_run_$*_commands
	$(if $(filter $*,$(dhmk_stamped_targets)),touch $@)
	$(if $(filter clean,$*),rm -f $(dhmk_rules_mk)\
	    $(foreach t,$(dhmk_stamped_targets),debian/dhmk_$(t)))
	# "$*" is complete

.PHONY: $(foreach t,$(dhmk_standard_targets),dhmk_run_$(t)_commands \
    dhmk_pre_$(t) dhmk_post_$(t) \
    $(foreach c,$(dhmk_$(t)_commands),dhmk_pre_$(t)_$(c) dhmk_post_$(t)_$(c)))

# Implicitly delegate other targets to debian/dhmk_% ones. Hence the top
# targets (build, configure, install ...) are still cancellable.
%: debian/dhmk_%
	@echo "$@ action has been completed successfully."

.SECONDEXPANSION:

# Relationships (depends/prerequisites)
$(foreach t,$(dhmk_standard_targets),debian/dhmk_$(t)): debian/dhmk_%: $$(foreach d,$$(dhmk_%_depends),debian/dhmk_$$d)

# Generate command chains for the standard targets
$(foreach t,$(dhmk_standard_targets),dhmk_run_$(t)_commands): dhmk_run_%_commands: dhmk_pre_% $$(foreach c,$$(dhmk_%_commands),dhmk_pre_%_$$(c) dhmk_post_%_$$(c)) dhmk_post_%

endif # ifeq (dhmk_override_info_mode,yes)

