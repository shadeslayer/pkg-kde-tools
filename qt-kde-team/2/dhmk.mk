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

ifndef dhmk_this_makefile

dhmk_this_makefile := $(lastword $(MAKEFILE_LIST))
dhmk_top_makefile := $(firstword $(MAKEFILE_LIST))
dhmk_stamped_targets = configure build-indep build-arch build
dhmk_dynamic_targets = install-indep install-arch install binary-indep binary-arch binary clean
dhmk_standard_targets = $(dhmk_stamped_targets) $(dhmk_dynamic_targets)
dhmk_indeparch_targets = build install binary
dhmk_rules_mk = debian/dhmk_rules.mk
dhmk_dhmk_pl := $(dir $(dhmk_this_makefile))dhmk.pl

# Variables holding all (incl. -indep, -arch) targets for each action
$(foreach t,$(dhmk_indeparch_targets),$(eval dhmk_$(t)_targets = $(t)-indep $(t)-arch))
$(foreach t,$(filter-out %-arch %-indep,$(dhmk_standard_targets)),\
    $(eval dhmk_$(t)_targets += $(t)))

# A helper routine to set additional command options
set_command_options = $(foreach t,$(filter $(or $3,%),$(dhmk_standard_targets)),\
                        $(foreach c,$(filter $1,$(dhmk_$(t)_commands)),\
                          $(eval $(t)_$(c) $2)))

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
dhmk_run_command = $(or $(call dhmk_override_cmd,override_$(call butfirstword,$1,_)),$($1) $(DHMK_OPTIONS))

# Generate {pre,post}_{target}_{command} targets for each target+command
$(foreach t,$(dhmk_standard_targets),$(foreach c,$(dhmk_$(t)_commands),pre_$(t)_$(c))): pre_%:
	$(call dhmk_run_command,$*) $(and $(DH_INTERNAL_OPTIONS),# [$(DH_INTERNAL_OPTIONS)])
$(foreach t,$(dhmk_standard_targets),$(foreach c,$(dhmk_$(t)_commands),post_$(t)_$(c))): post_%:

# Export -a/-i options for indep/arch specific targets
$(foreach t,$(dhmk_indeparch_targets),debian/dhmk_$(t)-indep): export DH_INTERNAL_OPTIONS := -i
$(foreach t,$(dhmk_indeparch_targets),debian/dhmk_$(t)-arch):  export DH_INTERNAL_OPTIONS := -a

# Mark dynamic standard targets as PHONY
.PHONY: $(foreach t,$(dhmk_dynamic_targets),debian/dhmk_$(t))

# Create debian/dhmk_{action} targets.
# NOTE: dhmk_run_{target}_commands are defined below
$(foreach t,$(dhmk_standard_targets),debian/dhmk_$(t)): debian/dhmk_%:
	$(MAKE) -f $(dhmk_top_makefile) dhmk_run_$*_commands
	$(if $(filter $*,$(dhmk_stamped_targets)),touch $@)
	$(if $(filter clean,$*),rm -f $(dhmk_rules_mk)\
	    $(foreach t,$(dhmk_stamped_targets),debian/dhmk_$(t)))
	# "$*" is complete

.PHONY: $(foreach t,$(dhmk_standard_targets),dhmk_run_$(t)_commands \
    pre_$(t) post_$(t) \
    $(foreach c,$(dhmk_$(t)_commands),pre_$(t)_$(c) post_$(t)_$(c)))

# Implicitly delegate other targets to debian/dhmk_% ones. Hence the top
# targets (build, configure, install ...) are still cancellable.
%: debian/dhmk_%
	@echo "$@ action has been completed successfully."

.SECONDEXPANSION:

# Relationships (depends/prerequisites)
$(foreach t,$(dhmk_standard_targets),debian/dhmk_$(t)): debian/dhmk_%: $$(foreach d,$$(dhmk_%_depends),debian/dhmk_$$d)

# Generate command chains for the standard targets
$(foreach t,$(dhmk_standard_targets),dhmk_run_$(t)_commands): dhmk_run_%_commands: pre_% $$(foreach c,$$(dhmk_%_commands),pre_%_$$(c) post_%_$$(c)) post_%

endif # ifeq (dhmk_override_info_mode,yes)

endif # ifndef dhmk_this_makefile
