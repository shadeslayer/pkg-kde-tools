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

package Debian::PkgKde::Dhmk::DhCompat;

my $targets;
my %extra_cmd_opts;

sub _find_cmd_and_do {
    # &$proc($cmd_array_ref, $cmd_index_ref)
    my ($proc, $command) = @_;
    foreach my $tname (keys %$targets) {
        my $tcmds = $targets->{$tname}{cmds};
        for (my $i = 0; $i < @$tcmds; $i++) {
            if (!defined($command) || $tcmds->[$i] eq $command) {
                &$proc($tcmds, \$i);
            }
        }
    }
}

sub _escape_shell {
    my @opts = @_;
    s/'/'"'"'/g foreach @opts;
    if (wantarray) {
        return map({ "'$_'" } @opts);
    } else {
        return "'" . join("' '", @opts) . "'";
    }
}

############### Dh Addon API ############################

# Insert $new_command in sequences before $existing_command
sub insert_before {
    my ($existing_command, $new_command) = @_;
    return _find_cmd_and_do(sub {
            my ($cmds, $i) = ($_[0], ${$_[1]});
            if ($i == 0) {
                unshift @$cmds, $new_command;
            } else {
                my @tail = splice(@$cmds, $i);
                push @$cmds, $new_command, @tail;
            }
            ${$_[1]}++;
        }, $existing_command);
}

# Insert $new_command in sequences after $existing_command
sub insert_after {
    my ($existing_command, $new_command) = @_;
    return _find_cmd_and_do(sub {
            my ($cmds, $i) = ($_[0], ${$_[1]});
            my @tail = ($i < $#{$cmds}) ? splice(@$cmds, $i+1) : ();
#            print $#_, join("--", @tail), "\n";
            push @$cmds, $new_command, @tail;
            ${$_[1]}++;
        }, $existing_command);
}

# Remove $existing_command from the list of commands to run in all sequences.
sub remove_command {
    my ($existing_command) = @_;
    return _find_cmd_and_do(sub {
            my ($cmds, $i) = ($_[0], ${$_[1]});
            splice(@$cmds, $i, 1);
            ${$_[1]}--;
        }, $existing_command);
}

# Add $new_command to the beginning of the specified sequence. If the sequence
# does not exist, it will be created.
sub add_command {
    my ($new_command, $sequence) = @_;
    if (exists $targets->{$sequence}) {
        unshift @{$targets->{$sequence}{cmds}}, $new_command;
    } else {
        $targets->{$sequence} = { cmds => [ $new_command ], deps => "" };
    }
}

# Append $opt1, $opt2 etc. to the list of additional options which dh passes
# when running the specified $command.
sub add_command_options {
    my ($command, @opts) = @_;
    push @{$extra_cmd_opts{$command}}, @opts;
}

# Remove @opts from the list of additional options which dh passes when running
# the specified $command. If @opts is empty, remove all extra options
sub remove_command_options {
    my ($command, @opts) = @_;
    if (exists $extra_cmd_opts{$command}) {
        if (!@opts) {
            delete $extra_cmd_opts{$command};
        } else {
            my $re = "(\Q" . join("\E|\Q", @opts) . "\E)";
            $extra_cmd_opts{$command} = [ grep { !/^$re$/ } @{$extra_cmd_opts{$command}} ];
        }
    }
}

########### Main module subroutines ###################

# Initialize jail
sub init {
    my %opts = @_;
    $targets = $opts{targets};
}

# Load addons
sub load_addons {
    my @addons = @_;
    foreach my $addon (@addons) {
        my $mod="Debian::Debhelper::Sequence::$addon";
        $mod=~s/-/_/g;
        eval "use $mod";
        if ($@) {
            die "unable to load addon $addon: $@";
        }
    }

    # Merge $extra_cmd_opts to $targets
    foreach my $c (keys %extra_cmd_opts) {
        next if !@{$extra_cmd_opts{$c}};
        _find_cmd_and_do(sub {
                my ($cmds, $i) = ($_[0], ${$_[1]});
                $cmds->[$i] .= " " . _escape_shell(@{$extra_cmd_opts{$c}});
            }, $c);
    }

    return 1;
}

# Add extra options to each command
sub add_extraopts {
    my @opts;
    # Convert "--option value" syntax to --option=value like dh(1) would do
    foreach my $opt (@_) {
        if ($opt =~ /^-/) {
            push @opts, $opt;
        } elsif (@opts && $opts[$#opts] =~ /^--/) {
            $opts[$#opts] .= "=" . $opt;
        } else {
            push @opts, $opt;
        }
    }
    my $shescaped =" " . join(" ", map({ s/^'-/-O'-/; $_ } _escape_shell(@opts)));
    _find_cmd_and_do(sub {
        my ($cmds, $i) = ($_[0], ${$_[1]});
        $cmds->[$i] .= $shescaped;
    });
}

1;

package main;

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

sub parse_cmdline {
    my @addons;
    my @extraopts;
    my $optname = "";
    my $optval;
    my $opts_need_values = qr/with(?:out)?/;
    my $opts_no_values = qr//;
    foreach my $arg (@ARGV) {
        if ($optname eq "--") {
            $optval = $arg;
        } elsif ($optname && !defined $optval) {
            $optval = $arg;
        } elsif ($arg eq "--") {
            $optname = "--";
            $optval = undef;
        } elsif ($arg =~ /^--($opts_need_values)=(.*)$/) {
            $optname = $1;
            $optval = $2 || "";
        } elsif ($arg =~ /^--($opts_need_values)$/) {
            $optname = $1;
            $optval = undef;
        } elsif ($arg =~ /^--($opts_no_values)=(.*)$/) {
            die "option $1 does not accept a value";
        } elsif ($arg =~ /^--($opts_no_values)$/) {
            $optname = $1;
            $optval = "";
        } else {
            $optval = $arg;
        }
        if (defined $optval) {
            if ($optname eq "" || $optname eq "--") {
                push @extraopts, $optval;
                # Do not reset $optname
            } else {
                if ($optname =~ /^$opts_need_values$/) {
                    if ($optval eq "") {
                        die "option $optname requires a value";
                    }
                    if ($optname eq "with") {
                        push @addons, split(/,/, $optval);
                    } elsif ($optname eq "without") {
                        @addons = grep { $_ ne $optval } @addons;
                    } else {
                        die "internal bug: unrecognized dhmk.pl option: $optname (val: $optval)";
                    }
                } elsif ($optname =~ /^$opts_no_values$/) {
                    # No such options exist yet
                } else {
                    die "unrecognized command line option: $optname";
                }
                $optname = "";
                $optval = undef;
            }
        }
    }

    return ( addons => \@addons, extraopts => \@extraopts );
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
my $DHMK_RULES_FILE = "debian/dhmk_rules.mk";
my $RULES_FILE = "debian/rules";

eval {
    my $targets = parse_commands_file($COMMANDS_FILE);
    my %cmdopts = parse_cmdline();

    Debian::PkgKde::Dhmk::DhCompat::init(targets => $targets);
    if (@{$cmdopts{addons}}) {
        if (!Debian::PkgKde::Dhmk::DhCompat::load_addons(@{$cmdopts{addons}})) {
            die "unable to load requested dh addons: " . join(", ", @{$cmdopts{addons}});
        }
    }
    if (@{$cmdopts{extraopts}}) {
        Debian::PkgKde::Dhmk::DhCompat::add_extraopts(@{$cmdopts{extraopts}});
    }
    my $commands = get_commands($targets);
    my $overrides = calc_overrides([ keys %$commands ], $RULES_FILE);
    write_dhmk_rules($DHMK_RULES_FILE, $RULES_FILE, $targets, $overrides);
};
if ($@) {
    die "error: $@"
}
