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

package Debian::PkgKde::SymbolsHelper::String;

use strict;
use warnings;

use overload '""' => \&get_string;

sub new {
    my ($class, $str) = @_;
    return bless { str => $str }, $class;
}

sub init_string2_by_re {
    my ($self, $str2, $re, $values) = @_;
    my @str2 = split(//, $self->get_string());
    my $offset = 0;
    while ($str2 =~ m/$re/g) {
	my $key = $1;
	my $i = pos($str2) - length($&) - $offset;
	$str2[$i] = "$&";
	my $count = $i + length($values->{$key});
	for ($i++; $i < $count; $i++) {
	    $str2[$i] = undef;
	}
	$offset += length($&) - length($values->{$key});
    }
    $self->{str2} = \@str2;
}

sub substr {
    my ($self, $offset, $length, $repl1, $repl2) = @_;
    if (defined $repl2 || exists $self->{str2}) {
	# If str2 has not been created yet, create it
	if (!exists $self->{str2}) {
	    $self->{str2} = [ split(//, $self->{str}) ];
	}
	# Keep offset information intact with $repl1
	my @repl2;
	my $edit_str2 = 1;
	if (defined $repl2) {
	    @repl2 = map { undef } split(//, $repl1);
	    $repl2[0] = $repl2;
	} elsif ($length != length($repl1)) {
	    if (!defined $repl2) {
		for (my $i = 0; $i < length($repl1); $i++) {
		    if ($i < $length) {
			push @repl2, $self->{str2}[$offset+$i];
		    } else {
			push @repl2, undef;
		    }
		}
	    }
	} else {
	    $edit_str2 = 0;
	}
	splice @{$self->{str2}}, $offset, $length, @repl2 if $edit_str2;
    }
    substr($self->{str}, $offset, $length) = $repl1;
}

sub get_string {
    return shift()->{str};
}

sub has_string2 {
    return exists shift()->{str2};
}

sub get_string2_char {
    my ($self, $index) = @_;
    return $self->{str2}->[$index];
}

sub get_string2 {
    my $self = shift;
    if (defined $self->{str2}) {
	my $str = "";
	foreach my $s (@{$self->{str2}}) {
	    $str .= $s if defined $s;
	}
	return $str;
    }
    return $self->get_string();
}

1;
