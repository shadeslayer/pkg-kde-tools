package Debian::PkgKde::SymbolsHelper::Substs;

use strict;
use warnings;
use Debian::PkgKde::SymbolsHelper::Substs::VirtTable;
use Debian::PkgKde::SymbolsHelper::Substs::TypeSubst;
use base 'Exporter';

our @EXPORT = qw(%SUBSTS @SUBSTS @STANDALONE_SUBSTS @TYPE_SUBSTS);

my $NS = 'Debian::PkgKde::SymbolsHelper::Substs';

our @STANDALONE_SUBSTS = (
    "${NS}::VirtTable"->new(),
);

our @TYPE_SUBSTS = (  
    "${NS}::TypeSubst::size_t"->new(),
    "${NS}::TypeSubst::ssize_t"->new(),
    "${NS}::TypeSubst::int64_t"->new(),
    "${NS}::TypeSubst::uint64_t"->new(),
    "${NS}::TypeSubst::qreal"->new(),
);

my @CPP_TYPE_SUBSTS;
foreach my $subst (@TYPE_SUBSTS) {
    push @CPP_TYPE_SUBSTS, "${NS}::TypeSubst::Cpp"->new($subst);
}

our @SUBSTS = (
    @STANDALONE_SUBSTS,
    @TYPE_SUBSTS,
);

our %SUBSTS;
foreach my $subst (@SUBSTS, @CPP_TYPE_SUBSTS) {
    $SUBSTS{$subst->get_name()} = $subst;
}

1;
