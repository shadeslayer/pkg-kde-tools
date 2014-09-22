# A debhelper build system class for building KDE Frameworks 5 packages.
# It is based on cmake class but passes Frameworks 5 flags by default.
#
# Copyright: © 2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::kf5;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(error);
use Dpkg::Version qw();

use base 'Debian::Debhelper::Buildsystem::cmake';

sub DESCRIPTION {
    "CMake with KDE Frameworks 5 flags"
}

sub KF5_FLAGS_FILE {
    my $file = "kf5_flags";
    if (! -r $file) {
        $file = "/usr/share/pkg-kde-tools/lib/kf5_flags";
    }
    if (! -r $file) {
        error "kf5_flags file could not be found";
    }
    return $file;
}

# Use shell for parsing contents of the kf5_flags file
sub get_kf5_flags {
    my $this=shift;
    my $file = KF5_FLAGS_FILE;
    my ($escaped_flags, @escaped_flags);
    my $flags;

    # Read escaped flags from the file
    open(KF5_FLAGS, "<", $file) || error("unable to open KDE Frameworks 5 flags file: $file");
    @escaped_flags = <KF5_FLAGS>;
    chop @escaped_flags;
    $escaped_flags = join(" ", @escaped_flags);
    close KF5_FLAGS;

    # Unescape flags using shell
    $flags = `$^X -w -Mstrict -e 'print join("\\x1e", \@ARGV);' -- $escaped_flags`;
    return split("\x1e", $flags);
}

sub configure {
    my $this=shift;
    my @flags = $this->get_kf5_flags();

    return $this->SUPER::configure(@flags, @_);
}

1;
