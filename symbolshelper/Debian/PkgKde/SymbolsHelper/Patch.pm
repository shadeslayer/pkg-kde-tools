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

package Debian::PkgKde::SymbolsHelper::Patch;

use strict;
use warnings;
use base 'Exporter';

use File::Temp qw();
use IO::Handle;
use Dpkg::ErrorHandling;

our @EXPORT = qw(patch_symbolfile);

sub patch_symbolfile {
    my ($filename, $patchfh) = @_;

    # Copy current symbol file to temporary location
    my ($patchedfh, $patchedfn) = File::Temp::tempfile();
    open(my $fh, "<", $filename) or
	error("unable to open symbol file at '$filename'");
    while (<$fh>) {
	print $patchedfh $_;
    }
    $patchedfh->flush();
    close $fh;
    close $patchedfh;

    # Extract needed patch from the stream and adapt it to our needs
    # (filenames to patch).
    my ($patchsrc, $patcharch);
    my $is_patch;
    my $sameline = 0;
    while($sameline || ($_ = <$patchfh>)) {
	$sameline = 0;
	if (defined $is_patch) {
	    if (m/^(?:[+ -]|@@ )/) {
		# Patch continues
		print PATCH $_;
		$is_patch++;
	    } else {
		# Patch ended
		if (close(PATCH)) {
		    # Successfully patched
		    $patchsrc = undef;
		    # $patcharch stays set
		    # $is_patch stays set
		    last;
		} else {
		    # Failed to patch. continue searching for another patch
		    $sameline = 1;
		    $patchsrc = undef;
		    $patcharch = undef;
		    $is_patch = undef;
		    next;
		}
	    }
	} elsif (defined $patchsrc) {
	    if (m/^[+]{3}\s+\S+/) {
		# Found the patch portion. Write the patch header
		$is_patch = 0;
		open(PATCH, "| patch --posix --force --quiet -r- -p0 >/dev/null 2>&1")
		    or die "Unable to execute `patch` program";
		print PATCH "--- ", $patchedfn, "\n";
		print PATCH "+++ ", $patchedfn, "\n";
	    } else {
		$patchsrc = undef;
		$patcharch = undef;
	    }
	} elsif (m/^[-]{3}\s+(\S+)(?:\s+\((\S+)\s+(\S+)\))?/) {
	    $patchsrc = $1;
	    $patcharch = $2;
	}
    }
    # In case patch continued to the end of file, close it
    my $symfile;
    if(($patchsrc && close(PATCH)) || $is_patch) {
	# Patching was successful. Parse new SymbolFile and return it
	my %opts;
	$opts{file} = $patchedfn;
	$opts{arch} = $patcharch if defined $patcharch;
	$symfile = Debian::PkgKde::SymbolsHelper::SymbolFile->new(%opts);
    }

    unlink($patchedfn);
    return $symfile;
}

