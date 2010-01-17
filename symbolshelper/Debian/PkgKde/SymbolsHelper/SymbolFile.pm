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
