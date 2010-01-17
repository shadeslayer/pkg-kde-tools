package Debian::PkgKde::SymbolsHelper::SymbolFileCollection;

use strict;
use warnings;
use Debian::PkgKde::SymbolsHelper::Substs;
use Debian::PkgKde::SymbolsHelper::String;
use Debian::PkgKde::SymbolsHelper::SymbolFile;
use Dpkg::ErrorHandling;

sub new {
    my ($class, $arch) = @_;
    return bless { arch => $arch }, $class;
}

sub get_arch {
    my $self = shift;
    return $self->{arch};
}

sub load_symbol_files {
    my ($self, $files) = @_;

    return 0 if (exists $self->{symfiles});

    foreach my $arch (keys %$files) {
	$self->add_symbol_file(
	    Debian::PkgKde::SymbolsHelper::SymbolFile->new(
		file => $files->{$arch}, arch => $arch
	    ),
	);
    }

    return 1;
}

sub add_symbol_file {
    my ($self, $symfile) = @_;
    $self->{symfiles}{$symfile->{arch}} = $symfile;
}

sub get_symfile {
    my ($self, $arch) = @_;
    if (exists $self->{symfiles}) {
	$arch = $self->get_arch() unless defined $arch;
	return $self->{symfiles}{$arch};
    }
    return undef;
}

sub get_symfiles {
    my $self = shift;
    return values %{$self->{symfiles}};
}

sub get_group_name {
    my ($self, $rawname) = @_;

    my $str = Debian::PkgKde::SymbolsHelper::String->new($rawname);
    foreach my $subst (@SUBSTS) {
	$subst->neutralize($str);
    }
    return $str->get_string();
}

sub create_template_standalone {
    my $self = shift;
    return undef unless exists $self->{symfiles};

    foreach my $arch (keys %{$self->{symfiles}}) {
	$self->{symfiles}->{$arch}->detect_standalone_substs(1);
    }
    return $self->get_symfile();
}

sub create_template {
    my ($self, %opts) = @_;

    return undef unless exists $self->{symfiles};

    my $symfiles = $self->{symfiles};
    my $main_arch = $self->get_arch();
    my $main_symfile = $self->get_symfile();

    # Neutralize with standalone substs first.
    foreach my $arch (keys %$symfiles) {
	$symfiles->{$arch}->detect_standalone_substs(1);
    }

    # Group new symbols by fully arch-neutralized name
    my %grouped;
    foreach my $arch1 (keys %$symfiles) {
	foreach my $arch2 (keys %$symfiles) {
	    next if $arch1 eq $arch2;
	    my @new = $symfiles->{$arch1}->get_new_symbols($symfiles->{$arch2});
	    foreach my $n (@new) {
		my $g = $self->get_group_name($n->get_symbolname());
		my $s = $n->{soname};
		my $sym = $symfiles->{$arch1}{objects}{$s}{syms}{$n->get_symbolname()};
		if (exists $grouped{$s}{$g}{arches}{$arch1}) {
		    if ($grouped{$s}{$g}{arches}{$arch1}->get_string() ne $n->get_symbolname()) {
			warning("at least two new symbols get to the same group ($g) on $s/$arch1:\n" .
			    "  " . $grouped{$s}{$g}{arches}{$arch1}->get_symbolname() . "\n" .
			    "  " . $n->get_symbolname());
			# Ban group
			$grouped{$s}{$g}{banned} = "ambiguous";
		    }
		} else {
		    $sym->get_h_name()->{symbol} = $sym;
		    $grouped{$s}{$g}{arches}{$arch1} = $sym->get_h_name();
		}
	    }
	}
    }

    # Prepare for missing archs check
    my $arch_count = scalar(keys %$symfiles);
    my %arch_ok;
    my $arch_ok_i = 0;
    foreach my $arch (keys %$symfiles) {
	$arch_ok{$arch} = $arch_ok_i;
    }

    foreach my $soname (keys %grouped) {
	my $groups = $grouped{$soname};
	foreach my $groupname (keys %$groups) {
	    my $group = $groups->{$groupname};

	    # Check if the group is not banned 
	    next if exists $group->{banned};

	    # Check if the group is complete
	    my $count = scalar(keys %{$group->{arches}});
	    my $sym_arch = $main_arch;
	    my $arch_specific;
	    if ($count < $arch_count) {
		# Additional vtables are usual on armel
		# next if ($count == 1 && exists $group->{arches}{armel} && $group->{arches}{armel}->is_vtt());

		# Print incomplete groups
		$arch_ok_i++;
		warning("incomplete group '$groupname/$soname' ($count < $arch_count):");
		my %distinct_names;
		foreach my $arch (keys %{$group->{arches}}) {
		    push @{$distinct_names{$group->{arches}{$arch}->get_string()}}, $arch;
		    $arch_ok{$arch} = $arch_ok_i;
		}
		foreach my $name (sort keys %distinct_names) {
		    info("  $name on: " . join(" ", sort(@{$distinct_names{$name}})));
		}
		my $str = "";
		foreach my $arch (sort(keys %arch_ok)) {
		    $str .= "$arch " if (defined $arch_ok{$arch} && $arch_ok{$arch} != $arch_ok_i);
		}
		info("	- missing on: $str\n");

		# Schedule as arch-specific symbol
		$arch_specific = join(" ", sort(keys %{$group->{arches}}));
		# Determine symbol arch, prefer main_arch though
		if (!exists $group->{arches}{$main_arch}) {
		    $sym_arch = (keys %{$group->{arches}})[0];
		}
	    }

	    # Post process symbols in the group
	    my $main_symbol = $group->{arches}{$sym_arch}->{symbol};
	    foreach my $subst (@TYPE_SUBSTS) {
		if ($subst->detect($main_symbol->get_h_name(), $main_arch, $group->{arches})) {
		    $main_symbol->add_tag("subst");
		    # Make archsymbols arch independent with regard to his handler
		    foreach my $arch (keys %{$group->{arches}}) {
			$subst->neutralize($group->{arches}{$arch});
		    }
		}
	    }
	    if ($arch_specific) {
		$main_symbol->add_tag("arch", $arch_specific);
		if ($sym_arch ne $main_arch) {
		    $main_symfile->add_symbol($soname, $main_symbol);
		}
	    }
	}
    }

    # Finally, resync h_names
    foreach my $soname (keys %grouped) {
	$main_symfile->resync_soname_with_h_name($soname);
    }

    return $main_symfile;
}

1;
