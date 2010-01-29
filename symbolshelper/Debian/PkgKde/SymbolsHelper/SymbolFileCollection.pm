# Copyright (C) 2008-2010 Modestas Vainius <modax@debian.org>
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

package Debian::PkgKde::SymbolsHelper::SymbolFileCollection;

use strict;
use warnings;

use Dpkg::Arch qw(debarch_is);
use Dpkg::ErrorHandling;
use Dpkg::Version;
use Debian::PkgKde::SymbolsHelper::Substs;
use Debian::PkgKde::SymbolsHelper::String;
use Debian::PkgKde::SymbolsHelper::SymbolFile;

sub new {
    my ($class, $orig_symfile) = @_;
    unless ($orig_symfile->get_confirmed_version()) {
	error("original symbol file template must have 'Confirmed' header set");
    }
    return bless { orig_symfile => $orig_symfile,
                   new_arches => {},
                   new_non_latest => [],
                   symfiles => {},
                   versions => {},
                   latest => undef }, $class;
}

sub get_symfiles {
    my $self = shift;
    return values %{$self->{symfiles}};
}

sub get_symfile {
    my ($self, $arch) = @_;
    if (defined $arch) {
	return $self->{symfiles}{$arch};
    } else {
	return $self->{orig_symfile};
    }
}

# NOTE: latest may also include $orig fork()s if no symbol files with higher
# confirmed version have been added.
sub get_latest_version {
    my $self = shift;
    return $self->{latest};
}

sub get_latest_arches {
    my $self = shift;
    return @{$self->{versions}{$self->{latest}}};
}

sub get_new_arches {
    my $self = shift;
    return keys %{$self->{new_arches}};
}

# This will NEVER include $orig fork()s
sub get_new_non_latest_arches {
    my $self = shift;
    return @{$self->{new_non_latest}};
}

sub is_arch_latest {
    my ($self, $arch) = @_;
    return $self->get_symfile($arch)->get_confirmed_version() eq $self->{latest};
}

sub is_arch_new {
    my ($self, $arch) = @_;
    return exists $self->{new_arches}{$arch};
}

sub add_symfiles {
    my ($self, @symfiles) = @_;
    my $latest = $self->get_latest_version();
    foreach my $symfile (@symfiles) {
	my $arch = $symfile->get_arch();
	my $ver = $symfile->get_confirmed_version();
	unless ($ver) {
	    internerr("problem with %s symbol file: it must have 'Confirmed' header",
		$arch);
	}
	if ($self->get_symfile($arch)) {
	    error("you cannot add symbol file for the same arch (%s) more than once",
		$arch);
	}
	$self->{symfiles}{$arch} = $symfile;
	push @{$self->{versions}{$ver}}, $arch;
	if (!defined $latest ||
	    version_compare($ver, $latest) > 0)
	{
	    $latest = $ver;
	}
    }
    $self->{latest} = $latest;
}

sub fork_orig_symfile {
    my ($self, @arches) = @_;
    my @symfiles = $self->get_symfile()->fork(
	map +{ arch => $_ }, @arches
    );
    $self->add_symfiles(@symfiles);
    return @symfiles;
}

sub add_new_symfiles {
    my ($self, @symfiles) = @_;
    $self->{new_arches} = { %{$self->{new_arches}},
	map({ $_->{arch} => $_ } @symfiles) };
    $self->add_symfiles(@symfiles);

    # Recalc new_non_latest
    my $ver = $self->get_latest_version();
    my @new_non_latest;
    foreach my $arch ($self->get_new_arches()) {
	if (! $self->is_arch_latest($arch)) {
	    push @new_non_latest, $arch;
	}
    }
    $self->{new_non_latest} = \@new_non_latest;
}

sub calc_group_name {
    my ($self, $name, $arch, @substs) = @_;

    my $str = Debian::PkgKde::SymbolsHelper::String->new($name);
    foreach my $subst (@substs) {
	$subst->prep($str, $arch);
	$subst->neutralize($str, $arch);
    }
    return $str->get_string();
}

# Create a new template from the collection of symbol files 
sub create_template {
    my ($self, %opts) = @_;

    return undef unless $self->get_symfiles();

    my $orig = $self->get_symfile();
    my $orig_arch = $orig->get_arch();
    my $template = $orig->fork_empty();
    my $symfiles = $self->{symfiles};

    # Prepare original template and other arch specific symbol files (virtual
    # table stuff etc.).
    $orig->prepare_for_templating();
    foreach my $symfile ($self->get_symfiles()) {
	$symfile->prepare_for_templating();
    }

    # Group new symbols by fully arch-neutralized name or, if unsupported,
    # simply by name.
    my (%gsubsts, %gother);
    foreach my $arch1 (undef, keys %$symfiles) {
	my $symfile1 = $self->get_symfile($arch1);
	foreach my $arch2 (keys %$symfiles, undef) {
	    my $symfile2 = $self->get_symfile($arch2);

	    next if ($arch1 || '') eq ($arch2 || '');
	    my @new = $symfile1->get_new_symbols($symfile2, with_optional => 1);
	    foreach my $n (@new) {
		my $s = $n->{soname};
		# Get a real reference
		my $sym = $symfile1->get_symbol_object($n, $s);
		my $group;

		unless (defined $sym) {
		    internerr("get_symbol_object() was unable to lookup new symbol");
		}
		# Substitution detection is only supported for regular symbols
		# and c++ aliases.
		if (! $n->is_pattern() || $n->get_alias_type() eq "c++") {
		    my $substs = ($n->has_tag("c++")) ? \@CPP_TYPE_SUBSTS : \@TYPE_SUBSTS;
		    my $groupname = $self->calc_group_name($n->get_symbolname(), $arch1, @$substs);

		    # Prep for substs
		    if (not $sym->{h_prepped}) {
			my $h_name = $sym->get_h_name();
			foreach my $subst (@$substs) {
			    $subst->prep($h_name, $arch1);
			}
			$sym->{h_prepped} = 1;
		    }
		    unless (exists $gsubsts{$s}{$groupname}) {
			$gsubsts{$s}{$groupname} =
			    Debian::PkgKde::SymbolsHelper::SymbolFileCollection::Group->new($substs);
		    }
		    $group = $gsubsts{$s}{$groupname};
		} else {
		    # Symbol of some other kind. Then just group by name
		    my $name = $n->get_symbolname();
		    unless (exists $gother{$s}{$name}) {
			$gother{$s}{$name} =
			    Debian::PkgKde::SymbolsHelper::SymbolFileCollection::Group->new();
		    }
		    $group = $gother{$s}{$name};
		}

		# Add symbol to the group
		$group->add_symbol($arch1, $sym);
		# "Touch" the $orig symbol if that's what we are dealing with
		$sym->{h_touched} = 1 if ! defined $arch1;
		if (! defined $arch2 && ! defined $group->get_symbol()) {
		    # We need to associate this group with $orig deprecated symbol
		    # if such exists.
		    my $sym2 = $symfile2->get_symbol_object($n, $s);
		    if (defined $sym2) {
			$sym2->{h_touched} = 1;
			$group->add_symbol(undef, $sym2);
		    }
		}
	    }
	}
    }

    # Readd all untouched symbols in $orig back to the $template
    foreach my $soname ($orig->get_sonames()) {
	foreach my $sym ($orig->get_symbols($soname), $orig->get_soname_patterns($soname)) {
	    if (!exists $self->{h_touched}) {
		$template->add_symbol($soname, $sym);
	    }
	}
    }

    # Process substs groups (%gsubsts) first
    foreach my $soname (keys %gsubsts) {
	my $groups = $gsubsts{$soname};

	foreach my $groupname (keys %$groups) {
	    my $group = $groups->{$groupname};

#	    print "group: $groupname", "\n";

	    # Take care of ambiguous groups
	    if ($group->is_ambiguous()) {
		my $byname = $group->regroup_by_name();
		my @byname;
		foreach my $grp (values %$byname) {
		    if (my $sym = $grp->calc_properties($self)) {
			push @byname, $sym->get_symbolspec(1);
			$template->add_symbol($soname, $sym);
		    }
		}
		if (@byname) {
		    info("ambiguous symbols for subst detection (%s). Processed by name:\n" .
		         "  %s", "$groupname/$soname", join("\n  ", @byname));
		}
		next;
	    }

	    # Calculate properties and detect substs.
	    if (my $sym = $group->calc_properties($self)) {
		# Then detect substs
		my $substs_arch = ($group->has_symbol($orig_arch)) ?
		    $orig_arch : ($group->get_arches())[0];
		if ($group->detect_substs($substs_arch)) {
			my $substs_sym = $group->get_symbol($substs_arch);
			$sym->add_tag("subst");
			$sym->reset_h_name($substs_sym->get_h_name());
		}

		# Finally add to template
		$template->add_symbol($soname, $sym);
	    } else {
	    }
	}
    }

    # Now process others groups (%gother). Just calculate properties (arch
    # tags) and add to the template.
    foreach my $soname (keys %gother) {
	my $groups = $gother{$soname};
	foreach my $groupname (keys %$groups) {
	    my $group = $groups->{$groupname};
	    if (my $sym = $group->calc_properties($self)) {
		$template->add_symbol($soname, $sym);
	    }
	}
    }

    # Finally, resync h_names
    foreach my $soname ($template->get_sonames()) {
	$template->resync_soname_with_h_name($soname);
    }

    return $template;
}

package Debian::PkgKde::SymbolsHelper::SymbolFileCollection::Group;

sub new {
    my ($class, $substs) = @_;
    return bless {
	arches => {},
	orig => undef,
	result => undef,
	substs => $substs}, $class;
}

sub has_symbol {
    my ($self, $arch) = @_;
    return (defined $arch) ? exists $self->{arches}{$arch} : $self->{orig};
}

sub get_symbol {
    my ($self, $arch) = @_;
    return (defined $arch) ? $self->{arches}{$arch} : $self->{orig};
}

sub get_arches {
    my $self = shift;
    return keys %{$self->{arches}};
}

sub get_result {
    my $self = shift;
    return $self->{result};
}

sub init_result {
    my ($self, $based_on_arch) = @_;
    $self->{result} = $self->get_symbol($based_on_arch)->dclone();
    return $self->{result};
}

sub add_symbol {
    my ($self, $arch, $sym) = @_;

    if (my $esym = $self->get_symbol($arch)) {
	if ($esym != $sym) {
	    # Another symbol already exists in this group for $arch.
	    # Add to other syms
	    push @{$self->{ambiguous}{$arch || ''}}, $sym;
	}
	# Otherwise, don't do anything. This symbol has already been added.
	return 0;
    } else {
	if (defined $arch) {
	    $self->{arches}{$arch} = $sym;
	} else {
	    $self->{orig} = $sym;
	}
	return 1;
    }
}

sub is_ambiguous {
    my $self = shift;
    return exists $self->{ambiguous};
}

# Regroup ambiguous symbols by symbol name
sub regroup_by_name {
    my $self = shift;
    my %groups;

    foreach my $arch (undef, $self->get_arches()) {
	my $sym = $self->get_symbol($arch);
	if (defined $sym) {
	    my $name = $sym->get_symbolname();
	    unless (exists $groups{$name}) {
		$groups{$name} = ref($self)->new();
	    }
	    my $group = $groups{$name};
	    $group->add_symbol($arch, $sym);
	}
    }
    if (exists $self->{ambiguous}) {
	foreach my $arch (keys %{$self->{ambiguous}}) {
	    foreach my $sym (@{$self->{ambiguous}{$arch}}) {
		$arch = undef if ! $arch;
		if (defined $sym) {
		    my $name = $sym->get_symbolname();
		    unless (exists $groups{$name}) {
			$groups{$name} = ref($self)->new();
		    }
		    my $group = $groups{$name};
		    $group->add_symbol($arch, $sym);
		}
	    }
	}
    }

    return \%groups;
}

sub are_symbols_equal {
    my $self = shift;
    my @arches = $self->get_arches();
    my $name = $self->get_symbol(shift @arches);
    foreach my $arch (@arches) {
	if ($self->get_symbol($arch)->get_symbolname() ne $name) {
	    $name = undef;
	    last;
	}
    }
    return $name;
}


# Calculate group properties and instantiates 'result'. At the moment, this
# method will take care of arch tags and deprecated status. "Result" symbol is
# returned if symbol is not useless in the group.
sub calc_properties {
    my ($self, $collection) = @_;

    # NOTE: if the symbol is NOT present in the group on the arch, it either:
    # 1) is not present on that arch;
    # 2) is deprecated on that arch;
    # 3) does not concern that arch.

    my @latest = $collection->get_latest_arches();
    my @non_latest = $collection->get_new_non_latest_arches();
    my $total_arches = scalar(@latest) + scalar(@non_latest);
    my (%add, %deprecate);
    my ($dont_add_all, $dont_deprecate_all) = (0, 0);

    my $osym = $self->get_symbol();
    my $result;

    if (defined $osym) {
	# The symbol exists in the template
	my @oarches;
	if ($osym->has_tag("arch")) {
	    @oarches = split(/[\s,]+/, $osym->get_tag_value("arch"))
	}
	$result = $self->init_result(); # base result on original
	foreach my $arch (@latest) {
	    if ($osym->arch_is_concerned($arch)) {
		if ($self->has_symbol($arch)) {
		    # The symbol is NOT missing on all latest concerned arches.
		    # Hence do not deprecate it on all.
		    $dont_deprecate_all++;
		} else {
		    # Add to the list of arches the symbol should be removed
		    # from
		    $deprecate{$arch} = 1;
		}
	    } else {
		if ($self->has_symbol($arch)) {
		    # The symbol is NEW on the latest non-concerned arch. Add
		    # to the list.
		    $add{$arch} = 1;
		} else {
		    # The symbol is NOT NEW on all latest non-concerned arches.
		    # We will need arch tag.
		    $dont_add_all++;
		}
	    }
	}

	if (keys %deprecate && ! $dont_deprecate_all && ! keys %add) {
	    if (!$osym->{deprecated} || $osym->is_optional()) {
		$result->{deprecated} = $collection->get_latest_version();
	    }
	} elsif (keys %add && (@oarches == 0 || scalar(keys %add) > 1) &&
	         ! $dont_add_all && ! keys %deprecate) {
	    # Do not remove arch tag if it already exists and we based
	    # our findings only on a single arch.
	    $result->{deprecated} = 0;
	    $result->delete_tag("arch");
	} else {
	    # We will need to add appropriate arch tag. But in addition,
	    # collect info from NEW non-latest arches (provided we had
	    # info about them from latest)
	    foreach my $arch (@non_latest) {
		if ($osym->arch_is_concerned($arch)) {
		    $deprecate{$arch} = 1
			if ! $self->has_symbol($arch) &&
			   keys(%deprecate) > 0 && ! exists $add{$arch};
		} else {
		    $add{$arch} = 1
			if $self->has_symbol($arch) &&
			   keys(%add) > 0 && ! exists $deprecate{$arch};
		}
	    }

	    if (keys(%add) || keys(%deprecate)) {
		$osym->{deprecated} = 0;
		if (@oarches > 0) {
		    my @narches;
		    # We need to combine original and new data
		    foreach my $arch (@oarches) {
			my $not_arch;
			$not_arch = $1 if $arch =~ /^!+(.*)$/;
			unless (($not_arch && exists $add{$not_arch}) ||
			        exists $deprecate{$arch})
			{
			    push @narches, $arch;
			}
		    }
		    unshift @narches, sort(keys %add);
		    unshift @narches, sort(keys %deprecate);
		    $result->add_tag("arch", join(" ", sort @narches));

		    # After sorting, the 'arch' expression may be invalid due
		    # to aliases used in the original. Check.
		    my $fail = 0;
		    foreach my $arch (keys %add) {
			unless ($result->arch_is_concerned($arch)) {
			    $fail = 1;
			    last;
			}
		    }
		    if (! $fail) {
			foreach my $arch (keys %deprecate) {
			    if ($result->arch_is_concerned($arch)) {
				$fail = 1;
				last;
			    }
			}
		    }
		    if ($fail) {
			# Set unsorted @narches
			$result->add_tag("arch", join(" ", @narches));
		    }
		} else {
		    # If deprecated on all but a single arch, add that one
		    if ($total_arches > 2 && scalar(keys %deprecate) == $total_arches-1) {
			foreach my $arch (@latest, @non_latest) {
			    if (! exists $deprecate{$arch}) {
				$result->add_tag("arch", "$arch");
				last;
			    }
			}
		    } else {
			$result->add_tag("arch",
			    join(" ", map({ "!".$_ } sort(keys %deprecate)), sort(keys %add)));
		    }
		}
	    }
	}
    } else {
	# Symbol template does not exist. This symbol is definitely NEW
	foreach my $arch (@latest) {
	    if ($self->has_symbol($arch)) {
		# The symbol is NEW on the latest arch. Add to the list.
		$add{$arch} = 1;
	    } else {
		# The symbol is NOT NEW on all latest non-concerned arches.
		# We will need arch tag.
		$dont_add_all++;
	    }
	}
	if (keys %add) {
	    $result = $self->init_result((keys %add)[0]);
	    if (! $dont_add_all) {
		$result->{deprecated} = 0;
		$result->delete_tag("arch");
	    } else {
		# We will need to add appropriate arch tag. But in addition,
		# collect info from NEW non-latest arches
		foreach my $arch (@non_latest) {
		    if ($self->has_symbol($arch)) {
			$add{$arch} = 1;
		    }
		}
		# Use !missing_arch if only a single arch is missing
		if ($total_arches > 2 && scalar(keys %add) == $total_arches - 1) {
		    foreach my $arch (@latest, @non_latest) {
			if (! exists $add{$arch}) {
			    $result->add_tag("arch", "!$arch");
			    last;
			}
		    }
		} else {
		    $result->add_tag("arch", join(" ", sort(keys %add)));
		}
	    }
	}
    }
    return $result;
}

sub detect_substs {
    my ($self, $main_arch) = @_;

    my %h_names = map { $_ => $self->get_symbol($_)->get_h_name() } $self->get_arches();
    my $h_name = $h_names{$main_arch};
    delete $h_names{$main_arch};

    my @substs;
    foreach my $subst (@{$self->{substs}}) {
	if ($subst->detect($h_name, $main_arch, \%h_names)) {
	    push @substs, $subst;
	    # Make other h_names arch independent with regard to this handler.
	    foreach my $arch (keys %h_names) {
		$subst->neutralize($h_names{$arch}, $arch);
	    }
	}
    }
    return @substs;
}

1;
