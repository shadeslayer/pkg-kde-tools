package Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff;
our @ISA = qw( Debian::PkgKde::SymHelper::Handler );

use strict;
use warnings;
use Debian::PkgKde::SymHelper::Handler;

sub new {
    return Debian::PkgKde::SymHelper::Handler::new(@_);
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
package Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::size_t;
our @ISA = qw( Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff );

use strict;
use warnings;

sub new {
    my $self = Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::new(@_);
    $self->{substvar} = "{size_t}";
    $self->{main_type} = "j"; # unsigned int
    $self->{type_re} = "[jm]";
    return $self;
}

sub get_predef_arch_params {
    my ($self, $arch) = @_;

    # Mult should be 1 on 32bit arches and 2 on 64bit arches and so on
    my $params = { type => "j" }; # unsigned int
    $params->{type} = "m" if ($arch =~ /amd64|ia64|alpha|s390/); # unsigned long
    return $params;
}

package Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::ssize_t;
our @ISA = qw( Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff );

use strict;
use warnings;

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
package Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::qreal;
our @ISA = qw( Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff );

use strict;
use warnings;

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
