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

1;
