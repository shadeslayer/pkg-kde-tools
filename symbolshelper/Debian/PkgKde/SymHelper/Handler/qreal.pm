package Debian::PkgKde::SymHelper::Handler::qreal;
our @ISA = qw( Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff );

use strict;
use warnings;
use Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff; 

sub new {
    my $self = Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::new(@_);
    $self->{substvar} = "{qreal}";
    $self->{main_type} = "d"; # unsigned int
    $self->{type_re} = "[fd]";
    return $self;
}

sub get_predef_arch_params {
    my ($self, $arch) = @_;

    # Mult should be 1 on 32bit arches and 2 on 64bit arches and so on
    my $params = { type => "d" }; # int
    $params->{type} = "f" if ($arch =~ /arm/); # unsigned long
    return $params;
}

1;
