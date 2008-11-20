package Debian::PkgKde::SymHelper::Symbol2;
our @ISA = qw(Debian::PkgKde::SymHelper::Symbol);

use strict;
use warnings;
use Debian::PkgKde::SymHelper::Symbol;

sub new {
    my $symbol = $_[1];
    my $self = Debian::PkgKde::SymHelper::Symbol::new(@_);
    my @lvl2 = split(//, $symbol);
    $self->{lvl2} = \@lvl2;
    return $self;
}

sub substr {
    my ($self, $offset, $length, $repl1, $repl2) = @_;
    my @repl = map { undef } split(//, $repl1);
    $repl[0] = $repl2;
    splice @{$self->{lvl2}}, $offset, $length, @repl;
    return Debian::PkgKde::SymHelper::Symbol::substr($self, $offset, $length, $repl1);
}

sub get_symbol2 {
    my $self = shift;
    my $str = "";
    foreach my $s (@{$self->{lvl2}}) {
        $str .= $s if defined $s;
    }
    return $str;
}

1;
