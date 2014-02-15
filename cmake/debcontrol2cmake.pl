#!/usr/bin/perl

# Copyright (C) 2011 Modestas Vainius <modax@debian.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

use strict;
use warnings;

use Dpkg::Control::Info;
use Dpkg::Control;
use Dpkg::Arch;

sub samearch {
    my $arch = shift;
    my @archlist = split(/\s+/, shift);

    foreach my $a (@archlist) {
        if (system("dpkg-architecture", "-a$arch", "-i$a") == 0) {
            return 1;
        }
    }

    return 0;
}

# Parse command line arguments
my @fields;
my $prefix = "debcontrol_";
for (my $i = 0; $i < @ARGV; $i++) {
    if ($ARGV[$i] eq "-F") {
        push @fields, $ARGV[++$i];
    } elsif ($ARGV[$i] =~ /^-F(.+)$/) {
        push @fields, $1;
    } elsif ($ARGV[$i] eq "-s") {
        $prefix = $ARGV[++$i];
    } elsif ($ARGV[$i] =~ /^-s(.+)$/) {
        $prefix = $1;
    }
}

my $arch = Dpkg::Arch::get_build_arch();

# Retrieve requested fields and generate set statements
my $control = Dpkg::Control::Info->new("debian/control");
foreach my $pkg ($control->{source}, @{$control->{packages}}) {
    my $pkgok;
    my $pkgname = ($pkg->get_type() ==  CTRL_INFO_SRC) ? "Source" : $pkg->{Package};
    next if $pkg->get_type() == CTRL_INFO_PKG && !samearch($arch, $pkg->{"Architecture"});
    foreach my $field (@fields) {
        my $val;
        if (exists $pkg->{$field}) {
            $val = $pkg->{$field};
        } elsif (my $f = $pkg->find_custom_field($field)) {
            $val = $pkg->{$f};
        }
        if (defined $val) {
            $pkgok = 1;
            printf "set(%s%s_%s \"%s\")\n", $prefix, $pkgname, $field, $val;
        }
    }
    if ($pkgok) {
        printf "list(APPEND %spackages \"%s\")\n", $prefix, $pkgname;
    }
}
