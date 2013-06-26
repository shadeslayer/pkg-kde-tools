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

package Debian::PkgKde::SymbolsHelper::Substs;

use strict;
use warnings;
use Debian::PkgKde::SymbolsHelper::Substs::TypeSubst;
use base 'Exporter';

our @EXPORT = qw(%SUBSTS @SUBSTS @STANDALONE_SUBSTS @TYPE_SUBSTS @CPP_TYPE_SUBSTS);

my $NS = 'Debian::PkgKde::SymbolsHelper::Substs';

our @STANDALONE_SUBSTS = (
);

our @TYPE_SUBSTS = (
    "${NS}::TypeSubst::size_t"->new(),
    "${NS}::TypeSubst::ssize_t"->new(),
    "${NS}::TypeSubst::int64_t"->new(),
    "${NS}::TypeSubst::uint64_t"->new(),
    "${NS}::TypeSubst::qptrdiff"->new(),
    "${NS}::TypeSubst::quintptr"->new(),
    "${NS}::TypeSubst::intptr_t"->new(),
    "${NS}::TypeSubst::qreal"->new(),
);

our @CPP_TYPE_SUBSTS;
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
