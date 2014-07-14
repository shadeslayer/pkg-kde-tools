# Copyright (C) 2008-2010 Modestas Vainius <modax@debian.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst;

# Do not produce subroutine redefined warnings when running this through
# syntax check. Based on http://www.perlmonks.org/?node_id=389286
BEGIN {
    $INC{'Debian/PkgKde/SymbolsHelper/Substs/TypeSubst.pm'} ||= __FILE__;
}

# Operates on %l% etc. same length types that cannot be presented in demangled
# symbols. Used by ::Cpp wrapper.
package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::CppPrivate;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my ($class, $base) = @_;
    my $self = $class->SUPER::new();
    $self->{base} = $base;
    $self->{'length'} = 3; # raw type + length('%%')
    $self->{substvar} = '{' . $self->get_name() . '}';
    $self->{types} = [ map { '%' . $_ . '%' } @{$base->{types}} ];
    return $self;;
}

sub get_name {
    my $self = shift;
    return "c++:" . $self->{base}->get_name();
}

sub get_types_re {
    my $self = shift;
    unless (exists $self->{types_re}) {
	my $s = '%[' . join("", @{$self->{base}{types}}) . ']%';
	$self->{types_re} = qr/$s/;
    }
    return $self->{types_re};
}


sub _expand {
    my ($self, $arch) = @_;
    return '%'.$self->{base}->_expand($arch).'%';
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

my %CPPRE_MAP = (
    '%m%' => qr/\bunsigned long(?! long)\b/,
    '%j%' => qr/\bunsigned int\b/,
    '%i%' => qr/\b(?<!unsigned )int\b/,
    '%l%' => qr/\b(?<!unsigned )long(?! long)\b/,
    '%x%' => qr/\b(?<!unsigned )long long\b/,
    '%y%' => qr/\bunsigned long long\b/,
    '%f%' => qr/\bfloat\b/,
    '%d%' => qr/\bdouble\b/,
);

sub new {
    my ($class, $base) = @_;
    my $self = $class->SUPER::new();
    $self->{private} =
	Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::CppPrivate->new($base);
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return $CPP_MAP{$self->{private}{base}->_expand($arch)};
}

sub get_name {
    my $self = shift;
    return $self->{private}->get_name();
}

# In order for detect()/neutralize() to work, all substs must be of the same
# length. Therefore replace demangled names with %l% etc.
sub prep {
    my ($self, $rawname, $arch) = @_;

    # We need to prepare $rawname only once for all Cpp substs
    return if exists $rawname->{cpp_prepped};

    my $str = "$rawname";
    foreach my $key (keys %CPPRE_MAP) {
	my $re = $CPPRE_MAP{$key};
	while ($str =~ /$re/g) {
	    my $l = length($&);
	    $rawname->substr(pos($str)-$l, $l, $key, $&);
	    $str = "$rawname" if $l != length($key);
	}
    }
    $rawname->{cpp_prepped} = 1;
}

sub detect {
    my $self = shift;
    return $self->{private}->detect(@_);
}

sub neutralize {
    my $self = shift;
    return $self->{private}->neutralize(@_);
}

sub hinted_neutralize {
    my $self = shift;
    return $self->{private}->hinted_neutralize(@_);
}

sub verify_at {
    my $self = shift;
    return $self->{private}->verify_at(@_);
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::size_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{size_t}";
    $self->{types} = [ qw(m j) ]; # unsigned long / unsigned int
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /^(amd64|kfreebsd-amd64|ia64|alpha|s390|s390x|sparc64|ppc64|ppc64el|mips64|mips64el|arm64)$/) ? 'm' : 'j';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::ssize_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{ssize_t}";
    $self->{types} = [ qw(l i) ]; # long / int
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /^(amd64|kfreebsd-amd64|ia64|alpha|s390|s390x|sparc64|ppc64|ppc64el|mips64|mips64el|arm64)$/) ? 'l' : 'i';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::int64_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{int64_t}";
    $self->{types} = [ qw(l x) ]; # long / long long
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /^(amd64|kfreebsd-amd64|ia64|alpha|s390x|sparc64|ppc64|ppc64el|mips64|mips64el|arm64)$/) ? 'l' : 'x';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::uint64_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{uint64_t}";
    $self->{types} = [ qw(m y) ]; # unsigned long / unsigned long long
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /^(amd64|kfreebsd-amd64|ia64|alpha|s390x|sparc64|ppc64|ppc64el|mips64|mips64el|arm64)$/) ? 'm' : 'y';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::qptrdiff;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{qptrdiff}";
    $self->{types} = [ qw(x i) ]; # long long / int
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /^(amd64|kfreebsd-amd64|ia64|alpha|s390x|sparc64|ppc64|ppc64el|mips64|mips64el|arm64)$/) ? 'x' : 'i';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::quintptr;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{quintptr}";
    $self->{types} = [ qw(y j) ]; # unsigned long long / unsigned int
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /^(amd64|kfreebsd-amd64|ia64|alpha|s390x|sparc64|ppc64|ppc64el|mips64|mips64el|arm64)$/) ? 'y' : 'j';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::intptr_t;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{intptr_t}";
    $self->{types} = [ qw(l i) ]; # long / int
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /^(amd64|kfreebsd-amd64|ia64|alpha|s390x|sparc64|ppc64|ppc64el|mips64|mips64el|arm64)$/) ? 'l' : 'i';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst::qreal;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Substs::TypeSubst';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{substvar} = "{qreal}";
    $self->{types} = [ qw(d f) ]; # double / float
    return $self;
}

sub _expand {
    my ($self, $arch) = @_;
    return ($arch =~ /^(arm|armeb|armel|armhf|sh4)$/) ? 'f' : 'd';
}

package Debian::PkgKde::SymbolsHelper::Substs::TypeSubst;

use strict;
use warnings;
use base 'Debian::PkgKde::SymbolsHelper::Subst';

# NOTE: recursive
use Debian::PkgKde::SymbolsHelper::Substs;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{'length'} = 1; # Basic typesubt must be one letter
    return $self;
}

sub get_name {
    my $self = shift;
    return substr($self->{substvar}, 1, -1);
}

sub get_types_re {
    my $self = shift;
    unless (exists $self->{types_re}) {
	my $s = '[' . join("", @{$self->{types}}) . ']';
	$self->{types_re} = qr/$s/;
    }
    return $self->{types_re};
}

sub neutralize {
    my ($self, $rawname) = @_;
    my $ret = 0;
    my $str = "$rawname";
    my $l = $self->{'length'};
    my $re = $self->get_types_re();

    while ($str =~ /$re/g) {
	$rawname->substr(pos($str)-$l, $l, $self->{types}->[0]);
	$ret = 1;
    }
    return ($ret) ? $rawname : undef;
}

sub hinted_neutralize {
    my ($self, $rawname, $hint) = @_;
    my $hintstr = $hint->{str2};
    my $ret = 1;
    my $l = $self->{'length'};

    for (my $i = 0; $i < @$hintstr; $i++) {
	if (defined $hintstr->[$i] && $hintstr->[$i] eq $self->{substvar}) {
	    $rawname->substr($i, $l, $self->{types}->[0], $self->{substvar});
	    $ret = 1;
	}
    }
    return ($ret) ? $rawname : undef;
}

sub detect {
    my ($self, $rawname, $arch, $arch_rawnames) = @_;

    my $l = $self->{'length'};
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

    return 0 unless defined $s2;

    # Verify subst and replace it with types[0] and substvar
    my $ret = 0;
    search_next: for (my $pos = 0; ($pos = index($s1, $t1, $pos)) != -1; $pos++) {
	# Verify on the selected $a2
	if ($t2 eq substr($s2, $pos, $l)) {
	    # Maybe subst is already there?
	    if ($rawname->has_string2() &&
	        (my $char = $rawname->get_string2_char($pos)))
	    {
		if ($char eq $self->{substvar}) {
		    # Nothing to do
		    $ret = 1;
		    $pos += $l-1;
		    next search_next;
		} elsif ($char =~ /^{(.*)}$/) {
		    # Another subst. Verify it
		    # NOTE: %SUBSTS might not work here due to recursive "use"
		    my $othersubst = $Debian::PkgKde::SymbolsHelper::Substs::SUBSTS{$1};
		    if (defined $othersubst && $othersubst->verify_at($pos, $arch_rawnames)) {
			$ret = 1;
			next search_next;
		    }
		}
	    }
	    # Now verify detection on other arches
	    if ($self->verify_at($pos, $arch_rawnames)) {
		$rawname->substr($pos, $l, $self->{types}->[0], $self->{substvar});
		$ret = 1;
		$pos += $l-1;
	    }
	}
    }
    return $ret;
}

sub verify_at {
    my ($self, $pos, $arch_rawnames) = @_;
    my $l = $self->{'length'};
    my $verified = 1;
    foreach my $a (keys %$arch_rawnames) {
	my $t = $self->expand($a);
	if ($t ne substr($arch_rawnames->{$a}, $pos, $l)) {
	    $verified = 0;
	    last;
	}
    }
    return $verified;
}

1;
