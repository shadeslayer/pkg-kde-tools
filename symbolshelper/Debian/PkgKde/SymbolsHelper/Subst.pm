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

# Prepare $rawname before detect()/neutralize()
# my ($self, $rawname, $arch) = @_;
sub prep {
}

# Make the raw symbol name architecture neutral
# my ($self, $rawname) = @_;
sub neutralize {
    return undef;
}

# Hinted neutralize where $hint is an already "detected"
# SymbolsHelper::String
# my ($self, $rawname, $hint) = @_;
sub hinted_neutralize {
    return undef;
}

# Detect if the substitution can be applied to a bunch of
# arch specific raw names.
# my ($self, $rawname, $arch, $arch_rawnames) = @_;
sub detect {
    return 0;
}

# Verifies if the subst is correct at $pos
# my ($self, $pos, $arch_rawnames) = @_;
sub verify_at {
    return undef;
}

1;
