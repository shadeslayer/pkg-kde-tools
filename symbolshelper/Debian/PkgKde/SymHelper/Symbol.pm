package Debian::PkgKde::SymHelper::Symbol;

use strict;
use warnings;

sub new {
    my ($cls, $symbol, $arch) = @_;
    return bless { symbol => $symbol, arch => $arch }, $cls;
}

sub substr {
    my ($self, $offset, $length, $repl) = @_;
    substr($self->{symbol}, $offset, $length) = $repl;
}

sub get_symbol {
    return shift()->{symbol};
}

sub get_arch {
    return shift()->{arch};
}

sub eq {
    my $self = shift;
    my $other = shift;
    return $self->{symbol} eq $other->{symbol};
}

sub is_vtt {
    return shift()->get_symbol() =~ /^_ZT[VT]/;
}

1;
