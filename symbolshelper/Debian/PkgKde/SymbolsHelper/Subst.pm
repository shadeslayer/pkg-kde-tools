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

package Debian::PkgKde::SymbolsHelper::Subst;

use strict;
use warnings;

sub new {
    my ($class, %opts) = @_;
    return bless { cache => {}, %opts }, $class;
}

sub get_name {
    my $self = shift;
    # Must be overriden
}

sub _expand {
    my ($self, $arch, $val) = @_;
    # Must be overriden
}

# $subst is here in order to support substs with values
sub expand {
    my ($self, $arch, $val) = @_;
    my $cache = ($val) ? "${arch}__$val" : $arch;
    unless (exists $self->{cache}{$cache}) {
	$self->{cache}{$cache} = $self->_expand($arch, $val);
    }
    return $self->{cache}{$cache};
}

# Make the raw symbol name architecture neutral
sub neutralize {
    my ($self, $rawname) = @_;
    return undef;
}

# Detect if the substitution can be applied to a bunch of
# arch specific raw names.
sub detect {
    my ($self, $rawname, $arch, $arch_rawnames) = @_;
    return undef;
}

1;