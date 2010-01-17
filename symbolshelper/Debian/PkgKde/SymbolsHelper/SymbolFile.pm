package Debian::PkgKde::SymbolsHelper::SymbolFile;

use strict;
use warnings;
use base 'Dpkg::Shlibs::SymbolFile';

use Dpkg::ErrorHandling;
use Debian::PkgKde::SymbolsHelper::Symbol;
use Debian::PkgKde::SymbolsHelper::Substs;

# Use Debian::PkgKde::SymbolsHelper::Symbol as base symbol
sub load {
    my ($self, $file, $seen, $obj_ref, $base_symbol) = @_;
    unless (defined $base_symbol) {
	$base_symbol = 'Debian::PkgKde::SymbolsHelper::Symbol';
    }
    return $self->SUPER::load($file, $seen, $obj_ref, $base_symbol);
}

sub get_symbols {
    my ($self, $soname) = @_;
    if (defined $soname) {
	my $obj = (ref $soname) ? $soname : $self->{objects}{$soname};
	return values %{$obj->{syms}};
    } else {
	my @syms;
	foreach my $soname (keys %{$self->{objects}}) {
	    push @syms, $self->get_symbols($soname);
	}
	return @syms;
    }
}

sub resync_soname_with_h_name {
    my ($self, $soname) = @_;
    my $obj = (ref $soname) ? $soname : $self->{objects}{$soname};

    # We need this to avoid removal of symbols which names clash when renaming	  
    my %rename;
    foreach my $symkey (keys %{$obj->{syms}}) {
	my $sym = $obj->{syms}{$symkey};
	my $h_name = $sym->get_h_name();
	$sym->{symbol} = $h_name->get_string();
	$sym->{symbol_templ} = $h_name->get_string2();
	if ($sym->get_symbolname() ne $symkey) {
	    $rename{$sym->get_symbolname()} = $sym;
	    delete $obj->{syms}{$symkey};
	}
    }
    foreach my $newname (keys %rename) {
	$obj->{syms}{$newname} = $rename{$newname};
    }
}

# Detects (or just neutralizes) substitutes which can be guessed
# from symbol name alone.
sub detect_standalone_substs {
    my ($self, $detect) = @_;

    foreach my $sym ($self->get_symbols()) {
        my $str = $sym->get_h_name();
        foreach my $subst (@STANDALONE_SUBSTS) {
	    if ($detect) {
	        $subst->detect($str, $self->{arch});
	    } else {
	        $subst->neutralize($str);
	    }
	}
    }
    foreach my $soname (keys %{$self->{objects}}) {
        # Rename soname object with data in h_name
	$self->resync_soname_with_h_name($soname);
    }
}

sub mark_cpp_templinst_as_optional {
    my $self = shift;
    foreach my $sym (grep { not $_->is_optional() } $self->get_symbols()) {
	if ($sym->detect_cpp_templinst()) {
	    $sym->add_tag("optional", "templinst");
        }
    }
}

sub handle_virtual_table_symbols {
    my $self = shift;
    foreach my $sym (grep { $_->get_symboltempl() =~ /^_ZT[Chv]/ } $self->get_symbols()) {
	$sym->upgrade_templ_to_cpp_alias();
    }
}

sub merge_lost_symbols_to_template {
    my ($self, $origsymfile, $newsymfile) = @_;
    my $count = 0;
    # Note: $origsymfile should normally be result of  $self->substitute()

    # Process symbols which are missing (lost) in $newsymfile
    for my $n ($newsymfile->get_lost_symbols($origsymfile)) {
	my $soname = $n->{soname};
	my $sym = $n->{name};
	my $origsyms = $origsymfile->{objects}{$soname}{syms};
	my $newsyms = $newsymfile->{objects}{$soname}{syms};

	my $mysym = (exists $origsyms->{$sym}{oldname}) ?
	    $origsyms->{$sym}{oldname} : $sym;
	if (exists $newsyms->{$sym}) {
	    $self->{objects}{$soname}{syms}{$mysym} = $newsyms->{$sym};
	} else {
	    # Mark as missing
	    $self->{objects}{$soname}{syms}{$mysym}{deprecated} = "LOST UNKNOWNVER";
	}
	$count++;
    }
    return $count;
}

sub get_new_symbols_as_symbfile {
    my ($self, $ref) = @_;
    my $deps = [ 'dummy dep' ];

    if (my @newsyms = $self->get_new_symbols($ref)) {
	my $newsymfile = new Debian::PkgKde::SymHelper::SymbFile();
	$newsymfile->clear();

	for my $n (@newsyms) {
	    my $soname = $n->{soname};
	    my $sym = $n->{name};

	    $newsymfile->{objects}{$soname}{syms}{$sym} =
		$self->{objects}{$soname}{syms}{$sym};
	    $newsymfile->{objects}{$soname}{deps} = $deps;
	}
	return $newsymfile;
    } else {
	return undef;
    }
}

sub merge_symbols_from_symbfile {
    my ($self, $symfile, $warn_about_collisions) = @_;

    while (my ($soname, $sonameobj) = each(%{$symfile->{objects}})) {
	my $mysyms = $self->{objects}{$soname}{syms};
	$mysyms = {} unless (defined $mysyms);

	while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
	    if (exists $mysyms->{$sym}) {
		warning("$sym exists in both symfiles. Keeping the old one\n")
		    if ($warn_about_collisions)
	    } else {
		$mysyms->{$sym} = $info;
	    }
	}
	$self->{objects}{$soname}{syms} = $mysyms;
    }
}

sub handle_min_version {
    my ($self, $version, %opts) = @_;

    foreach my $sym ($self->get_symbols()) {
	if (defined $version) {
    	    if ($version) {
		$sym->set_min_version($version, %opts);
    	    } else {
		$sym->normalize_min_version(%opts);
	    }
	}
    }
}

1;
