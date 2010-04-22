# Copyright (C) 2010 Modestas Vainius <modax@debian.org>
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

package Debian::PkgKde;

use File::Spec;

use base qw(Exporter);
our @EXPORT = qw(get_program_name
    printmsg info warning errormsg error syserr usageerr);
our @EXPORT_OK = qw(find_datalibdir setup_datalibdir find_exe_in_path DATALIBDIR);

# Determine datalib for current script. It depends on the context the script
# was executed from.
use constant DATALIBDIR => '/usr/share/pkg-kde-tools/lib';

sub find_datalibdir {
    my @hintfiles = @_;
    my @dirs;
    if ($0 =~ m@^(.+)/[^/]+$@) {
	push @dirs, "$1/datalib";
    }
    push @dirs, DATALIBDIR;

    # Verify if the dir and hint files exist
    my $founddir;
    foreach my $dir (@dirs) {
	my $ok;
	if ($dir && -d $dir) {
	    $ok = 1;
	    foreach my $hint (@hintfiles) {
		unless (-e "$dir/$hint") {
		    $ok = 0;
		    last;
		}
	    }
	}
	if ($ok) {
	    $founddir = $dir;
	    last;
	}
    }

    return $founddir;
}

# Add DATALIBDIR to @INC if the script is NOT being run from the source tree.
sub setup_datalibdir {
    my $dir = find_datalibdir(@_);
    if ($dir) {
	unshift @INC, DATALIBDIR if $dir eq DATALIBDIR;
    } else {
	error("unable to locate pkg-kde-tools library directory");
    }
    return $dir;
}

sub find_exe_in_path {
    my ($exe) = @_;
    if (File::Spec->file_name_is_absolute($exe)) {
	return $exe;
    } elsif ($ENV{PATH}) {
	foreach my $dir (split /:/, $ENV{PATH}) {
	    my $path = File::Spec->catfile($dir, $exe);
	    if (-x $path) {
		return $path;
	    }
	}
    }
    return undef;
}

{
    my $progname;
    sub get_program_name {
	unless (defined $progname) {
	    $progname = ($0 =~ m,/([^/]+)$,) ? $1 : $0;
	}
	return $progname;
    }
}

sub format_message {
    my $type = shift;
    my $format = shift;

    my $msg = sprintf($format, @_);
    return ((defined $type) ?
	get_program_name() . ": $type: " : "") . "$msg\n";
}

sub printmsg {
    print STDERR format_message(undef, @_);
}

sub info {
    print STDERR format_message("info", @_);
}

sub warning {
    warn format_message("warning", @_);
}

sub syserr {
    my $msg = shift;
    die format_message("error", "$msg: $!", @_);
}

sub errormsg {
    print STDERR format_message("error", @_);
}

sub error {
    die format_message("error", @_);
}

sub usageerr {
    die format_message("usage", @_);
}

1;
