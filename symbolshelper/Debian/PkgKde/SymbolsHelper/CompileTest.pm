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

package Debian::PkgKde::SymbolsHelper::CompileTest;

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use Dpkg::ErrorHandling;

sub new {
    my ($cls, $compiler, $lib) = @_;

    my $tmpdir = tempdir();
    my $sourcefile = "testcomp";
    my $out = "testcomp";
    my $cmd;

    error("Unable to create a temporary directory for test compilation") unless $tmpdir;

    if ($compiler =~ /gcc/) {
	$sourcefile .= ".c";
    } elsif ($compiler =~ /g\+\+/) {
	$sourcefile  .= ".cpp";
    } else {
	error("Unrecognized compiler: $compiler");
    }
    $sourcefile = File::Spec::catfile($tmpdir, $sourcefile);

    if ($lib) {
	$cmd = "$compiler -shared -fPIC";
	$out .= ".so";
    } else {
	$cmd = "$compiler";
    }
    $out = File::Spec::catfile($tmpdir, $out);

    my $self = bless { tmpdir => $tmpdir,
	sourcefile => $sourcefile, out => $out }, $cls;
    $self->set_cmd($cmd);
    return $self;
}

sub set_cmd {
    my ($self, $cmd) = @_;
    $self->{cmd} = "$cmd $self->{sourcefile} -o $self->{out}";
}

sub compile {
    my ($self, $sourcecode) = @_;

    open(SOURCE, ">", $self->{sourcefile})
	or error("Unable to open temporary source file for writing: $self->{sourcefile}");
    print SOURCE $sourcecode
	or error("Unable to write to temporary source file $self->{sourcefile}");
    close(SOURCE);

    system($self->{cmd}) == 0 or error("Compilation failed: $self->{cmd}");
    return $self->get_output_file();
}

sub get_output_file {
    my $self = shift;
    return (-f $self->{out}) ? $self->{out} : undef;
}

sub rm {
    my $self = shift;
    system("rm -rf $self->{tmpdir}") == 0 or error("Unable to delete temporary directory: $self->{tmpdir}");
}

1;
