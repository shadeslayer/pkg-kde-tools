#!/usr/bin/perl

use strict;
use warnings;

use Dpkg::Control::Info;
use Dpkg::Control;

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

# Retrieve requested fields and generate set statements
my $control = Dpkg::Control::Info->new("debian/control");
foreach my $pkg ($control->{source}, @{$control->{packages}}) {
    my $pkgok;
    my $pkgname = ($pkg->get_type() ==  CTRL_INFO_SRC) ? "Source" : $pkg->{Package};
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
