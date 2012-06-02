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

package Debian::PkgKde::SymbolsHelper::Symbol;

use strict;
use warnings;
use base 'Dpkg::Shlibs::Symbol';

use Dpkg::Gettext;
use Dpkg::Shlibs::Cppfilt;
use Dpkg::Arch qw(get_valid_arches);
use Dpkg::ErrorHandling;
use Debian::PkgKde::SymbolsHelper::Substs;
use Debian::PkgKde::SymbolsHelper::String;

sub get_h_name {
    my $self = shift;
    if (!exists $self->{h_name}) {
	$self->{h_name} = Debian::PkgKde::SymbolsHelper::String->new(
	    $self->get_symbolname()
	);
	if (exists $self->{substs}) {
	    # We need to recreate string2 from the templ
	    $self->{h_name}->init_string2_by_re($self->get_symboltempl(),
		qr/\{([^}]+)\}/, $self->{substs});
	    if ($self->{h_name}->get_string2() ne $self->get_symboltempl()) {
		internerr("unsupported substitutions/alterations in the symbol template '%s'. " .
		    "Parsed as '%s'. Cannot continue.",
		    $self->get_symboltempl(), $self->{h_name}->get_string2());
	    }
	}
    }
    return $self->{h_name};
}

sub reset_h_name {
    my ($self, $new_h_name) = @_;
    if (defined $new_h_name) {
	$self->{h_name} = $new_h_name;
    } else {
	delete $self->{h_name};
    }
}

sub resync_name_with_h_name {
    my $self = shift;
    if (exists $self->{h_name}) {
	my $h_name = $self->{h_name};
	$self->set_symbolname($h_name->get_string(), $h_name->get_string2());
    }
}

# Needed for h_name above
sub get_substs {
    my $self = shift;
    return $self->{substs};
}

sub is_trunk_symbol {
    my $self = shift;
    my $name = shift || $self->get_symbolname();
    # Based on: binutils/libiberty/cp-demangle.c:d_special_name()
    # c - DEMANGLE_COMPONENT_COVARIANT_THUNK: covariant return thunk to
    # C - DEMANGLE_COMPONENT_CONSTRUCTION_VTABLE: construction vtable for
    # h - DEMANGLE_COMPONENT_THUNK: non-virtual thunk to
    # v - DEMANGLE_COMPONENT_VIRTUAL_THUNK: virtual thunk to
    return $name =~ /^_ZT[Cchv]/;
}

sub initialize {
    my ($self, %opts) = @_;

    # Expand substvars
    if ($self->has_tag('subst')) {
	# Expand substitutions in the symbol name. See below.
	if ($self->expand_substitutions(%opts) == 0) {
	    # Redundant subst tag. Warn.
	    warning(_g("%s: no valid substitutions, 'subst' tag is redundant"),
		$self->get_symbolname());
	}
    }

    return $self->SUPER::initialize(%opts);
}

sub expand_substitutions {
    my ($self, %opts) = @_;
    my $symbol = $self->get_symbolname();
    my %substs;

    # Collect substitutions in the symbol name
    while ($symbol =~ /\{(([^}=]+)(?:=([^}]+))?)\}/g) {
	my $subst = $1;
	my $name = $2;
	my $val = $3;
	unless (exists $substs{$name}) {
	    my $substobj = $SUBSTS{$name};
	    if (defined $subst) {
		$substs{$subst} = $substobj->expand($opts{arch}, $val);
		if (!defined $substs{$subst}) {
		    error(_g("%s: unable to expand symbol substitution '%s'"), $symbol, $subst);
		}
	    } # If not defined, silently ignore.
	}
    }

    # Expand substitutions
    for my $subst (keys %substs) {
	$symbol =~ s/\Q{$subst}\E/$substs{$subst}/g;
    }

    $self->{symbol} = $symbol;
    $self->{substs} = \%substs;
    return keys %substs;
}

sub get_cppname {
    my $self = shift;
    unless (exists $self->{cppname}) {
	$self->{cppname} = ($self->get_symbolname() =~ /^_Z/) ?
	    cppfilt_demangle_cpp($self->get_symbolname()) :
	    undef;
    }
    return $self->{cppname};
}

sub detect_cpp_templinst() {
    my $self = shift;

    my $cppname = $self->get_cppname();
    if (defined $cppname) {
	# Prepare for tokenizing: wipe out unnecessary spaces
	$cppname =~ s/([,<>()])\s+/$1/g;
	$cppname =~ s/\s+([,<>()])/$1/g;
	$cppname =~ s/\s*((?:(?:un)?signed|volatile|restrict|const|long)[*&]*)\s*/$1/g;
	if (my @tokens = split(/\s+/, $cppname)) {
	    my $func;
	    if ($tokens[0] =~ /[(]/) {
		$func = $tokens[0];
	    } elsif ($#tokens >= 1 && $tokens[1] =~ /[(]/) {
		# The first token was return type, try the second
		$func = $tokens[1];
	    }
	    if (defined $func && $func =~ /<[^>]+>[^(]*[(]/) {
		return 1;
	    }
	}
    }
    return 0;
}

# Typically template instantiations are not useful public symbols
sub mark_cpp_templinst_as_optional {
    my ($self, @tag) = @_;
    @tag = ("optional", "templinst") unless @tag;
    if (!$self->is_optional() && $self->detect_cpp_templinst()) {
	$self->add_tag(@tag);
    }
}

# Converts symbol template to c++ alias converting substitutions as well.
# Returns converted template string or undef in case of failure.
sub convert_templ_to_cpp_alias {
    my ($self, $templ) = @_;
    $templ = $self->get_symboltempl() unless defined $templ;
    my $result;

    return undef unless $templ =~ /^_Z/;

    if (! $self->has_tag('subst')) {
	$result = cppfilt_demangle_cpp($templ);
    } else {
	my (%mangled, @possible_substs);

	# Collect possible symbol variants by expanding on all valid arches
	foreach my $arch (get_valid_arches()) {
	    $self->{symbol} = $templ;
	    @possible_substs = $self->expand_substitutions(arch => $arch);
	    push @{$mangled{$self->get_symbolname()}}, $arch;
	}

	# Prepare for checking of demangled symbols
	my (@demangled, @arches);
	foreach my $mangled (keys %mangled) {
	    my $d = cppfilt_demangle_cpp($mangled);
	    # Fail immediatelly if couldn't demangle a variant
	    return undef unless defined $d;

	    # Tokenize
	    push @demangled, [ split(/\b/, $d) ];
	    push @arches, $mangled{$mangled};
	}

	# Create a subst expansion result map for $main_arch
	my $main_arch = $arches[0][0];
	my %cppmap;
	foreach my $subst (@possible_substs) {
	    my $name = "c++:$subst";
	    # Can't handle a subst which does not have a c++ replacement
	    if (exists $SUBSTS{$name}) {
		my $cppsubst = $SUBSTS{$name};
		push @{$cppmap{$cppsubst->expand($main_arch)}}, $cppsubst;
	    } else {
		return undef;
	    }
	}

	# Now do detection
	my @result;
	my @expanded_size = map { 0 } @demangled;
	while (@{$demangled[0]} > 0) {
	    # Check if the token is not the same in all symbols (i.e. no subst here)
	    my $token = shift @{$demangled[0]};
	    my $ok = 1;
	    for (my $i = 1; $i < @demangled; $i++) {
		if ($token ne $demangled[$i][0]) {
		    $ok = 0;
		    last;
		}
	    }
	    if ($ok) {
		# Tokens match. Get next token and push to @result
		for (my $i = 1; $i < @demangled; $i++) {
		    shift @{$demangled[$i]};
		}
		push @result, $token;
	    } else {
		# Tokens do not match. We need to guess a subst
		my $found_subst;

		# Determine a set of candidate substs by expansion result
		# for $main_arch
		while (!exists $cppmap{$token}) {
		    my $next = shift @{$demangled[0]};
		    if (!defined $next) {
			return undef;
		    }
		    # Add up next token to this one and check again
		    $token .= $next;
		}

		# If we are here, a set of candidate substs has been found
		my $cand_substs = $cppmap{$token};

		# Now we need to pick a right candidate from candidates
		next_candidate: for my $cand_subst (@$cand_substs) {
		    # Expansion must be the same on index 0 arches
		    foreach my $arch (@{$arches[0]}) {
			if ($cand_subst->expand($arch) ne $token) {
			    next next_candidate;
			}
		    }

		    # On 1+ arches, $subst->expand() and our $demangled value must match
		    for (my $i = 1; $i < @arches; $i++) {
			my $archset = $arches[$i];
			my $expanded = $cand_subst->expand($archset->[0]);

			# Check if expansion is the same on all arches in the current set
			foreach my $arch (@$archset) {
			    if ($expanded ne $cand_subst->expand($arch)) {
				next next_candidate;
			    }
			}

			# Now actually check if $expanded matches what was demangled
			$expanded_size[$i] = scalar(my @s = split(/\b/, $expanded));
			if (join("", @{$demangled[$i]}[0..($expanded_size[$i]-1)]) ne $expanded) {
			    next next_candidate;
			}
		    }

		    # If we are here, candidate has been confirmed
		    $found_subst = $cand_subst;
		    last;
		}

		if (defined $found_subst) {
		    for (my $i = 1; $i < @demangled; $i++) {
			splice @{$demangled[$i]}, 0, ($expanded_size[$i]);
		    }
		    push @result, '{' . $found_subst->get_name() . '}';
		} else {
		    # Unable to find an appropriate subst
		    return undef;
		}
	    }
	}

	foreach my $demangled (@demangled) {
	    # Fail if demangling was not complete
	    return undef if @$demangled > 0;
	}

	$result = join("", @result);
    }
    return $result;
}

sub upgrade_virtual_table_symbol {
    my ($self, $arch) = @_;
    if ($self->is_trunk_symbol($self->get_symboltempl())) {
	my $newtempl = $self->convert_templ_to_cpp_alias();
	if (defined $newtempl) {
	    $self->set_symbolname($newtempl, $newtempl);
	    $self->add_tag("c++");
	    # Finally, reinitialize
	    $self->initialize(arch => $arch);
	}
	return $newtempl;
    }
    return undef;
}

sub set_min_version {
    my ($self, $version, %opts) = @_;

    $self->{minver} = $version
	if ($opts{with_deprecated} || !$self->{deprecated});
}

sub normalize_min_version {
    my ($self, %opts) = @_;

    if ($opts{with_deprecated} || !$self->{deprecated}) {
	my $minver = $self->{minver};
	if ($minver =~ m/-.*[^~]$/) {
	    unless($minver =~ s/-[01](?:$|[^\d-][^-]*$)//) {
		$minver =~ s/([^~])$/$1~/;
	    }
	    $self->{minver} = $minver;
	}
    }
}

sub handle_min_version {
    my ($self, $version, %opts) = @_;

    if (defined $version) {
	if ($version) {
	    return $self->set_min_version($version, %opts);
	} else {
	    return $self->normalize_min_version(%opts);
	}
    }
}

1;
