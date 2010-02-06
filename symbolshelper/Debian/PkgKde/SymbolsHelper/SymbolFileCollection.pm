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
                   confirmed_arches => [],
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

sub add_confirmed_arches {
    my ($self, @arches) = @_;
    foreach my $arch (@arches) {
	if ($self->get_symfile($arch)) {
	    error("new symbol file has already been added for arch (%s)", $arch);
	}
    }
    push @{$self->{versions}{$self->get_symfile()->get_confirmed_version()}},
	@arches;
    push @{$self->{confirmed_arches}}, @arches;
}

sub get_confirmed_arches {
    my ($self) = @_;
    return @{$self->{confirmed_arches}};
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

sub fork_orig_symfile {
    my ($self, @arches) = @_;
    my @symfiles = $self->get_symfile()->fork(
	map +{ arch => $_ }, @arches
    );
    return map { $_->{arch} => $_ } @symfiles;
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

sub get_symbols_regrouped_by_name {
    my ($self, $group) = @_;
    my $byname = $group->regroup_by_name();
    my @byname;
    foreach my $grp (sort values %$byname) {
	if (my $sym = $grp->calc_properties($self)) {
	    push @byname, $sym;
	}
    }
    return sort { $a->get_symboltempl() cmp $b->get_symboltempl() } @byname;
}

sub select_group {
    my ($self, $sym, $soname, $arch, $gsubsts, $gother) = @_;

    # Substitution detection is only supported for regular symbols and c++
    # aliases.
    if (! $sym->is_pattern() || $sym->get_alias_type() eq "c++") {
	my $substs = ($sym->has_tag("c++")) ? \@CPP_TYPE_SUBSTS : \@TYPE_SUBSTS;
	my $groupname = $self->calc_group_name($sym->get_symbolname(), $arch, @$substs);

	unless (exists $gsubsts->{$soname}{$groupname}) {
	    $gsubsts->{$soname}{$groupname} =
		Debian::PkgKde::SymbolsHelper::SymbolFileCollection::Group->new($substs);
	}
	return $gsubsts->{$soname}{$groupname};
    } else {
	# Symbol of some other kind. Then just group by name
	my $name = $sym->get_symbolname();
	unless (exists $gother->{$soname}{$name}) {
	    $gother->{$soname}{$name} =
		Debian::PkgKde::SymbolsHelper::SymbolFileCollection::Group->new();
	}
	return $gother->{$soname}{$name};
    }
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
    my %osymfiles = $self->fork_orig_symfile($self->get_new_arches());

    foreach my $arch ($self->get_new_arches()) {
	my $nsymfile = $self->get_symfile($arch);
	my $osymfile = $osymfiles{$arch};

	my @new = $nsymfile->get_new_symbols($osymfile, with_optional => 1);
	foreach my $n (@new) {
	    my $soname = $n->{soname};
	    my $nsym = $n->{symbol};
	    # Get a reference in the orig symfile if any
	    my $osym = $osymfile->get_symbol_object($nsym, $soname);

	    my $group = $self->select_group($nsym, $soname, $arch, \%gsubsts, \%gother);

	    # Add symbol to the group
	    $group->add_symbol($nsym, $arch);
	    $group->prep_substs($arch);

	    if (defined $osym) {
		my $origin = $osym->{h_origin_symbol};
		$group->add_symbol($origin);
		# "Touch" the origin symbol
		$origin->{h_touched} = 1;
	    }
	}

	my @lost = $nsymfile->get_lost_symbols($osymfile, with_optional => 1);
	foreach my $l (@lost) {
	    my $soname = $l->{soname};
	    my $sym = $l->{symbol};
	    my $origin = $sym->{h_origin_symbol};
	    my $group = $self->select_group($sym, $soname, $arch, \%gsubsts, \%gother);

	    $group->add_symbol($origin);
	    # "Touch" the origin symbol
	    $origin->{h_touched} = 1;
	}
    }

    # Fork confirmed symbols where it matters
    if (my @carches = $self->get_confirmed_arches()) {
	# Important for substs detection
	foreach my $soname (values %gsubsts) {
	    foreach my $group (values %$soname) {
		if ($group->get_arches() && (my $osym = $group->get_symbol())) {
		    foreach my $arch (@carches) {
			if ($osym->arch_is_concerned($arch)) {
			    my $nsym = $orig->fork_symbol($osym, $arch);
			    $group->add_symbol($nsym, $arch);
			    $group->prep_substs($arch);
			}
		    }
		}
	    }
	}
    }

    # Readd all untouched symbols in $orig back to the $template
    foreach my $soname ($orig->get_sonames()) {
	foreach my $sym ($orig->get_symbols($soname),
	                 $orig->get_patterns($soname))
	{
	    if (!exists $sym->{h_touched}) {
		$template->add_symbol($sym, $soname);
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
		if (my @byname = $self->get_symbols_regrouped_by_name($group)) {
		    $template->add_symbol($_, $soname) foreach @byname;
		    info("ambiguous symbols for subst detection (%s). Processed by name:\n" .
		         "  %s", "$groupname/$soname",
			join("\n  ", map { $_->get_symbolspec(1) } @byname));
		}
		next;
	    }
	    # Calculate properties and detect substs.
	    if (my $sym = $group->calc_properties($self)) {
		# Then detect substs (we need two or more arch specific symbols for that)
		my $substs_ok = 0;
		if (scalar($group->get_arches()) > 1 && ! $group->are_symbols_equal()) {
		    my $substs_arch = ($group->has_symbol($orig_arch)) ?
			$orig_arch : ($group->get_arches())[0];
		    if ($group->detect_substs($substs_arch)) {
			my $substs_sym = $group->get_symbol($substs_arch);
			$sym->add_tag("subst");
			$sym->reset_h_name($substs_sym->get_h_name());
			$substs_ok = $group->verify_substs();
		    }
		} else {
		    $substs_ok = 1;
		}

		if ($substs_ok) {
		    # Finally add to template
		    $template->add_symbol($sym, $soname);
		} else {
		    # Substitutions do not verify. Regroup by name what remains
		    foreach my $sym ($group->get_symbols()) {
			$sym->resync_name_with_h_name();
		    }
		    if (my @byname = $self->get_symbols_regrouped_by_name($group)) {
			$template->add_symbol($_, $soname) foreach @byname;
			info("possible incomplete subst detection (%s). Processed by name:\n" .
			     "  %s", "$groupname/$soname",
			     join("\n  ", map { $_->get_symbolspec(1) } @byname));
		    }
		}
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
		$template->add_symbol($sym, $soname);
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

sub get_symbols {
    my $self = shift;
    return values %{$self->{arches}};
}

sub get_result {
    my $self = shift;
    return $self->{result};
}

sub init_result {
    my ($self, $based_on_arch) = @_;
    $self->{result} = $self->get_symbol($based_on_arch)->clone();
    return $self->{result};
}

sub add_symbol {
    my ($self, $sym, $arch) = @_;

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
	    $group->add_symbol($sym, $arch);
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
		    $group->add_symbol($sym, $arch);
		}
	    }
	}
    }

    return \%groups;
}

sub are_symbols_equal {
    my $self = shift;
    my @arches = $self->get_arches();
    my $name;

    $name = ($self->get_symbol()) ?
	$self->get_symbol() : $self->get_symbol(shift @arches);
    $name = $name->get_symbolname();
    foreach my $arch (@arches) {
	if ($self->get_symbol($arch)->get_symbolname() ne $name) {
	    return 0;
	}
    }
    return 1;
}

# Verify if all substs have been replaced (i.e. hint-neutralized)
sub verify_substs {
    my $self = shift;
    my @arches = $self->get_arches();
    my $str = $self->get_symbol(shift @arches)->get_h_name()->get_string();
    foreach my $arch (@arches) {
	if ($self->get_symbol($arch)->get_h_name()->get_string() ne $str) {
	    return 0;
	}
    }
    return 1;
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
			$result->add_tag("arch", join(" ", sort @narches));
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

    # Bump symbol minver if new arches added
    if (defined $result && keys %add) {
	$result->{minver} = $collection->get_latest_version();
    }

    return $result;
}

sub prep_substs {
    my ($self, $arch) = @_;
    my $sym = $self->get_symbol($arch);
    my $h_name = $sym->get_h_name();
    foreach my $subst (@{$self->{substs}}) {
	$subst->prep($h_name, $arch);
    }
}

sub detect_substs {
    my ($self, $main_arch) = @_;

    my %h_names = map { $_ => $self->get_symbol($_)->get_h_name() } $self->get_arches();
    my $h_name = $h_names{$main_arch};

    my $detected = 0;
    foreach my $subst (@{$self->{substs}}) {
	if ($subst->detect($h_name, $main_arch, \%h_names)) {
	    $detected++;
	    # Make other h_names arch independent with regard to this handler.
	    foreach my $arch (keys %h_names) {
		$subst->hinted_neutralize($h_names{$arch}, $h_name);
	    }
	}
    }
    return $detected;
}

1;
