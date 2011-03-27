# A debhelper build system class for building KDE 4 packages.
# It is based on cmake class but passes KDE 4 flags by default.
#
# Copyright: © 2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::kde;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(error);
use Dpkg::Version qw();

use base 'Debian::Debhelper::Buildsystem::cmake';

sub DESCRIPTION {
    "CMake with KDE 4 flags"
}

sub KDE4_FLAGS_FILE {
    my $file = "kde4_flags";
    if (! -r $file) {
        $file = "/usr/share/pkg-kde-tools/lib/kde4_flags";
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
    my @flags = $this->get_kde4_flags();

    my $kdever = `dpkg-query -f='\${Version}' -W kdelibs5-dev 2>/dev/null`;
    if ($kdever) {
        if (Dpkg::Version::version_compare($kdever, "4:4.4.0") < 0) {
            # Skip RPATH if kdelibs5-dev is older than 4:4.4.0
            push @flags, "-DCMAKE_SKIP_RPATH:BOOL=ON";
        } elsif (Dpkg::Version::version_compare($kdever, "4:4.6.1") < 0) {
            # Manually set ENABLE_LIBKDEINIT_RUNPATH:BOOL=ON if kdelibs5-dev is
            # older than 4:4.6.1. Later kdelibs5-dev revisions enable this
            # automatically whenever CMAKE_BUILD_TYPE is set to Debian (default)
            push @flags, "-DENABLE_LIBKDEINIT_RUNPATH:BOOL=ON";
        }
    }

    return $this->SUPER::configure(@flags, @_);
}

1;
