package Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff;
our @ISA = qw( Debian::PkgKde::SymHelper::Handler::Base );

use strict;
use warnings;
use Debian::PkgKde::SymHelper::Handler::Base;

sub new {
    return Debian::PkgKde::SymHelper::Handler::Base::new(@_);
}

sub clean {
    my ($self, $symbol) = @_;
    my $sym = $symbol->get_symbol();
    my $ret = 0;
    while ($sym =~ m/$self->{type_re}/g) {
        $symbol->substr(pos($sym)-1, 1, $self->{main_type});
        $ret = 1;
    }
    return $ret;
}

sub detect {
    my ($self, $main_symbol, $archsymbols) = @_;

    my $s1 = $main_symbol->get_symbol();
    my $t1 = $self->get_arch_param("type", $main_symbol->get_arch());
    my ($s2, $t2, $a2);

    # Find architecture with other type
    while (($a2, my $symbol) = each(%$archsymbols)) {
        $t2 = $self->get_arch_param("type", $a2);
        if ($t2 ne $t1) {
            $s2 = $symbol->get_symbol();
            last;
        }
    }

    return 0 unless defined $s2;

    # Compare letter by letter until difference is found
    my @s1 = split(//, $s1);
    my @s2 = split(//, $s2);
    my $ret = 0;
    for (my $i = 0; $i <= $#s1; $i++) {
        if ($s1[$i] eq $t1 && $s2[$i] eq $t2) {
            $main_symbol->substr($i, 1, $self->{main_type}, $self->{substvar});
            $ret = 1;
        }
    }
    return $ret;
}

sub replace {
    my ($self, $substvar) = @_;
    if ($substvar =~ /^$self->{substvar}$/) {
        return $self->get_arch_param("type");
    } else {
        return undef;
    }
}

1;
