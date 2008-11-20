package Debian::PkgKde::SymHelper::Handler::ssize_t;
our @ISA = qw( Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff );

use strict;
use warnings;
use Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff; 

sub new {
    my $self = Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::new(@_);
    $self->{substvar} = "{ssize_t}";
    $self->{main_type} = "i"; # unsigned int
    $self->{type_re} = "[il]";
    return $self;
}

sub get_predef_arch_params {
    my ($self, $arch) = @_;

    # Mult should be 1 on 32bit arches and 2 on 64bit arches and so on
    my $params = { type => "i" }; # int
    $params->{type} = "l" if ($arch =~ /amd64|ia64|alpha|s390/); # unsigned long
    return $params;
}

1;
