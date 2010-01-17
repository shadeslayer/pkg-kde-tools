package Debian::PkgKde::SymbolsHelper::Substs::VirtTable;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Subst';

use Dpkg::ErrorHandling;
use Dpkg::Shlibs::Cppfilt;

# Expand support (for backwards compatibility)
# Neutralize support

sub get_name {
    "vt";
}

sub _expand {
    my ($self, $arch, $value) = @_;

    # Mult should be 1 on 32bit arches and 2 on 64bit arches
    my $mult = ($arch =~ /amd64|ia64|alpha/) ? 2 : 1;
    return $mult * $value;
}

sub subvt {
    my ($self, $rawname, $number, $stroffset) = @_;
    $rawname->substr($stroffset, length("$number"), "0",
	($self->{__detect__}) ? $number : undef);
    return 1;
}

sub find_ztc_offset {
    my ($self, $rawname) = @_;
    $rawname = "$rawname";

    # The idea behind the algorithm is that c++filt output does not
    # change when offset is changed.
    # e.g. _ZTCN6KParts15DockMainWindow3E56_NS_8PartBaseE

    my @matches = ($rawname =~ m/(\d+)_/gc);
    if (!@matches) {
        error("Invalid construction table symbol: $rawname");
    } elsif (@matches == 1) {
        # Found it
        return (pos($rawname) - length($1) - 1, $1);
    } else {
        # The idea behind the algorithm is that c++filt output does not
        # change when an offset is changed.
        $rawname =~ s/@[^@]+$//;
        my $demangled = cppfilt_demangle($rawname, 'auto');
        pos($rawname) = undef;
        while ($rawname =~ m/(\d+)_/g) {
            my $offset = $1;
            my $pos = pos($rawname) - length($offset) - 1;
            my $newsymbol = $rawname; 
            substr($newsymbol, $pos, length($offset)) = $offset + 1234;
            my $newdemangled = cppfilt_demangle($newsymbol, 'auto');
            return ($pos, $offset) if (defined $newdemangled && $newdemangled eq $demangled);
        }
        error("Unable to determine construction table offset position in symbol '$rawname'");
    }
}

sub neutralize {
    my ($self, $rawname) = @_;
    my $ret = 1;

    # construction vtable: e.g. _ZTCN6KParts15DockMainWindow3E56_NS_8PartBaseE
    if ($rawname =~ /^_ZTC/) {
        my ($pos, $num) = $self->find_ztc_offset($rawname);
        $ret = $self->subvt($rawname, $num, $pos) if ($num > 0);
    } elsif ($rawname =~ /^_ZThn(\d+)_/) {
        # non-virtual base override: e.g. _ZThn8_N6KParts13ReadWritePartD0Ev
        my $num = $1;
        $ret = $self->subvt($rawname, $num, 5) if ($num > 0);
    } elsif ($rawname =~ /^_ZTvn?(\d+)_(n?\d+)/) {
        # virtual base override, with vcall offset, e.g. _ZTv0_n12_N6KParts6PluginD0Ev
        my $voffset = $1;
        my $num = $2;
        my $numoffset = 4 + length("$voffset") + 1 + (($num =~ /^n/) ? 1 : 0);
        $num =~ s/^n//;

        $ret = $self->subvt($rawname, $voffset, 4) if ($voffset > 0);
        $ret = $self->subvt($rawname, $num, $numoffset) || $ret if ($num > 0);
    }
    return ($ret) ? $rawname : undef;
}

sub detect {
    my $self = shift;
    $self->{__detect__} = 1;
    my $ret = $self->neutralize(@_);
    delete $self->{__detect__};
    return $ret;
}

1;
