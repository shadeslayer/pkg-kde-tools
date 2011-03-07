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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

use strict;
use warnings;

use File::Basename qw();
use File::Spec;

sub parse_commands_file {
    my ($filename) = @_;
    my %targets;
    my $t;

    open (my $fh, "<", $filename) or
        die "unable to open dhmk commands file $filename: $!";

    # File format is:
    # target:
    # 	command1
    # 	command2
    # 	command3
    # 	...
    # Use $targetname in place of a command to insert commands from the
    # previously defined target.
    while (my $line = <$fh>) {
        chop $line;
        if ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
            next; # comment or empty line
        } elsif ($line =~ /^(\S.+):\s*(.*)$/) {
            $t = $1;
            $targets{$t}{deps} = $2 || "";
            $targets{$t}{cmds} = [];
        } elsif (defined $t) {
            if ($line =~ /^\s+(.*)$/) {
                my $c = $1;
                # If it's a variable, dereference it
                if ($c =~ /^\s*\$(\S+)\s*$/) {
                    if (exists $targets{$1}) {
                        push @{$targets{$t}{cmds}}, @{$targets{$1}{cmds}};
                    } else {
                        die "could not dereference variable \$$1. Target '$1' was not defined yet";
                    }
                } else {
                    push @{$targets{$t}{cmds}}, $c;
                }
            } else {
                die "dangling command '$line'. Missing target definition";
            }
        } else {
            die "invalid commands file syntax";
        }
    }
    close($fh);

    return \%targets;
}

sub get_commands {
    my ($targets) = @_;
    my %commands;
    foreach my $tname (keys %$targets) {
        my $t = $targets->{$tname}{cmds};
        foreach my $c (@$t) {
            if ($c =~ /^(\S+)/) {
                push @{$commands{$1}}, $tname;
            } else {
                die "internal error: unrecognized command '$c'";
            }
        }
    }
    return \%commands;
}

sub calc_overrides {
    my ($commands, $rules_file) = @_;
    my $magic = "##dhmk_no_override##";

    # Initialize all overrides first
    my %overrides;
    my @override_targets;
    foreach my $c (@$commands) {
        $overrides{$c} = 1;
        push @override_targets, "override_$c";
    }

    # Now remove overrides based on the rules file output
    open(my $make, "-|", "make", "-f", $rules_file, "-j1", "-n",
        "--no-print-directory",
        @override_targets,
        "dhmk_calc_overrides=yes") or
        die "unable to execute make for override calculation: $!";
    while (my $line = <$make>) {
        if ($line =~ /^$magic(.*)$/ && exists $overrides{$1}) {
            delete $overrides{$1};
        }
    }
    if (!close($make)) {
        die "make (calc_override) failed with $?";
    }

    return \%overrides;
}

sub write_dhmk_rules {
    my ($dhmk_file, $rules_file, $targets, $overrides) = @_;
    open (my $fh, ">", $dhmk_file) or
        die "unable to open dhmk rules file ($dhmk_file) for writing: $!";
    print $fh "# Action command sequences", "\n";
    foreach my $tname (keys %$targets) {
        my $t = $targets->{$tname};
        my @commands;
        foreach my $cline (@{$t->{cmds}}) {
            my $c = ($cline =~ /^(\S+)/) && $1;
            push @commands, $c;
            print $fh $tname, "_", $c, " = ", $cline, "\n";
        }
        print $fh "dhmk_", $tname, "_commands = ", join(" ", @commands), "\n";
        print $fh "dhmk_", $tname, "_depends = ", $t->{deps}, "\n";
        print $fh "\n";
    }
    print $fh "# Overrides", "\n";
    foreach my $o (sort keys %$overrides) {
        print $fh "dhmk_override_", $o, " = yes", "\n";
    }
    close($fh);
}

my $COMMANDS_FILE = File::Spec->catfile(File::Basename::dirname($0), "commands");
my $DHMK_RULES_FILE = $ARGV[0] || "debian/dhmk_rules.mk";
my $RULES_FILE = $ARGV[1] || "debian/rules";

eval {
    my $targets = parse_commands_file($COMMANDS_FILE);
    my $commands = get_commands($targets);
    my $overrides = calc_overrides([ keys %$commands ], $RULES_FILE);
    write_dhmk_rules($DHMK_RULES_FILE, $RULES_FILE, $targets, $overrides);
};
if ($@) {
    die "error: $@"
}
