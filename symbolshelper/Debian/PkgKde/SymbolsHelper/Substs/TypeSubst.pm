package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Subst';

sub get_name {
    my $self = shift;
    return substr($self->{substvar}, 1, -1);
}

sub neutralize {
    my ($self, $rawname) = @_;
    my $ret = 0;
    my $str = "$rawname";
    
    return undef unless exists $self->{type_re};

    while ($str =~ /$self->{type_re}/g) {
        $rawname->substr(pos($str)-1, 1, $self->{main_type});
        $ret = 1;
    }
    return ($ret) ? $rawname : undef;
}

sub detect {
    my ($self, $rawname, $arch, $arch_rawnames) = @_;

    my $s1 = $rawname;
    my $t1 = $self->expand($arch);
    my ($s2, $t2);

    # Find architecture with other type
    foreach my $a2 (keys %$arch_rawnames) {
        $t2 = $self->expand($a2);
        if ($t2 ne $t1) {
            $s2 = $arch_rawnames->{$a2};
            last;
        }
    }

    return undef unless defined $s2;

    # Compare letter by letter until difference is found
    my @s1 = split(//, $s1);
    my @s2 = split(//, $s2);
    my $ret = 0;
    for (my $i = 0; $i <= $#s1; $i++) {
        if ($s1[$i] eq $t1 && $s2[$i] eq $t2) {
            $rawname->substr($i, 1, $self->{main_type}, $self->{substvar});
            $ret = 1;
        }
    }
    return ($ret) ? $rawname : undef;
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::Cpp;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Subst';

my %CPP_MAP = (
    m => 'unsigned long',
    j => 'unsigned int',
    i => 'int',
    l => 'long',
    x => 'long long',
    y => 'unsigned long long',
    f => 'float',
    d => 'double',
);

sub new {
    my ($class, $base) = @_;
    return bless { base => $base }, $class;
}

sub _expand {
    my ($self, $arch) = @_;
    return $CPP_MAP{$self->{base}->_expand($arch)};
}

sub get_name {
    my $self = shift;
    return "c++:" . $self->{base}->get_name();
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::size_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{size_t}";
    $self->{main_type} = "m"; # unsigned long (amd64)
    $self->{type_re} = qr/[jm]/;
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /amd64|ia64|alpha|s390/) ? "m" : "j";
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::ssize_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{ssize_t}";
    $self->{main_type} = "l"; # long (amd64)
    $self->{type_re} = qr/[il]/;
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /amd64|ia64|alpha|s390/) ? 'l' : 'i';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::int64_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{int64_t}";
    $self->{main_type} = "l"; # long (amd64)
    $self->{type_re} = qr/[xl]/;
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /amd64|ia64|alpha/) ? 'l' : 'x';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::uint64_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{uint64_t}";
    $self->{main_type} = "m"; # unsigned long (64bit)
    $self->{type_re} = qr/[ym]/;
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /amd64|ia64|alpha/) ? 'm' : 'y';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::qreal;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{qreal}";
    $self->{main_type} = "d"; # double (not arm)
    $self->{type_re} = qr/[fd]/;
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /arm/) ? 'f' : 'd';
}

1;
