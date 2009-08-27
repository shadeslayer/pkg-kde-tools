# A debhelper build system class for building KDE 4 packages.
# It is based on cmake class but passes KDE 4 flags by default.
#
# Copyright: © 2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::kde;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(error);
use base 'Debian::Debhelper::Buildsystem::cmake';

sub DESCRIPTION {
    "CMake with KDE 4 flags"
}

sub KDE4_FLAGS_FILE {
    my $file = "kde4_flags";
    if (! -r $file) {
        $file = "/usr/share/pkg-kde-tools/kde4_flags";
    }
    if (! -r $file) {
        error "kde4_flags file could not be found";
    }
    return $file;
}

# Use shell for parsing contents of the kde4_flags file
sub get_kde4_flags {
    my $this=shift;
    my $file = KDE4_FLAGS_FILE;
    my ($escaped_flags, @escaped_flags);
    my $flags;

    # Read escaped flags from the file
    open(KDE4_FLAGS, "<", $file) || error("unable to open KDE 4 flags file: $file");
    @escaped_flags = <KDE4_FLAGS>;
    chop @escaped_flags;
    $escaped_flags = join(" ", @escaped_flags);
    close KDE4_FLAGS;

    # Unescape flags using shell
    $flags = `$^X -w -Mstrict -e 'print join("\\x1e", \@ARGV);' -- $escaped_flags`;
    return split("\x1e", $flags);
}

sub configure {
    my $this=shift;
    return $this->SUPER::configure($this->get_kde4_flags(), @_);
}

1;
