package Debian::PkgKde::SymHelper::Handler::VirtTable;
our @ISA = qw( Debian::PkgKde::SymHelper::Handler );

use Debian::PkgKde::SymHelper::CompileTest;
use Debian::PkgKde::SymHelper qw(error);
use Debian::PkgKde::SymHelper::Handler;

sub get_host_arch_params {
    my $params = {};
    my $c = new Debian::PkgKde::SymHelper::CompileTest("gcc");
    my $exe = $c->compile("#include <stdio.h>\nint main() { printf \"%d\\n\", sizeof(void*) \ 4; }");
    $params->{mult} = `$exe`;
    $c->rm();
    return $params;
}

sub get_predef_arch_params {
    my ($self, $arch) = @_;

    # Mult should be 1 on 32bit arches and 2 on 64bit arches and so on
    my $params = { mult => 1 };
    $params->{mult} = 2 if ($arch =~ /amd64|ia64|alpha/);
    return $params;
}

sub subvt {
    my ($self, $symbol, $number, $stroffset) = @_;
    my $l = length("$number");

    if ((my $mult = $self->get_arch_param("mult", $symbol->get_arch())) > 1) {
        $number /= $mult;
    }
    $symbol->substr($stroffset, $l, "$number", "{vt:$number}");
    return 1;
}

sub find_ztc_offset {
    my ($self, $symbol) = @_;

    # The idea behind the algorithm is that c++filt output does not
    # change when offset is changed.
    # e.g. _ZTCN6KParts15DockMainWindow3E56_NS_8PartBaseE

    my @matches = ($symbol =~ m/(\d+)_/gc);
    if (!@matches) {
        error("Invalid construction table symbol: $symbol");
    } elsif (@matches == 1) {
        # Found it
        return (pos($symbol) - length($1) - 1, $1);
    } else {
        # The idea behind the algorithm is that c++filt output does not
        # change when an offset is changed.
        $symbol =~ s/@[^@]+$//;
        my $demangled = `c++filt '$symbol'`;
        pos($symbol) = undef;
        while ($symbol =~ m/(\d+)_/g) {
            my $offset = $1;
            my $pos = pos($symbol) - length($offset) - 1;
            my $newsymbol = $symbol; 
            substr($newsymbol, $pos, length($offset)) = $offset + 1234;
            my $newdemangled = `c++filt '$newsymbol'`;
            return ($pos, $offset) if ($demangled eq $newdemangled);
        }
        error("Unable to determine construction table offset position in symbol '$symbol'");
    }
}

sub diff_symbol {
    my ($self, $symbol) = @_;
    my @diffs;
    my $sym = $symbol->get_symbol();
    my $ret = 0;

    # construction vtable: e.g. _ZTCN6KParts15DockMainWindow3E56_NS_8PartBaseE
    if ($sym =~ /^_ZTC/) {
        my ($pos, $num) = $self->find_ztc_offset($sym);
        $ret = $self->subvt($symbol, $num, $pos) if ($num > 0);
    } elsif ($sym =~ /^_ZThn(\d+)_/) {
        # non-virtual base override: e.g. _ZThn8_N6KParts13ReadWritePartD0Ev
        my $num = $1;
        $ret = $self->subvt($symbol, $num, 5) if ($num > 0);
    } elsif ($sym =~ /^_ZTvn?(\d+)_(n?\d+)/) {
        # virtual base override, with vcall offset, e.g. _ZTv0_n12_N6KParts6PluginD0Ev
        my $voffset = $1;
        my $num = $2;
        my $numoffset = 4 + length("$voffset") + 1 + (($num =~ /^n/) ? 1 : 0);
        $num =~ s/^n//;

        $ret = $self->subvt($symbol, $voffset, 4) if ($voffset > 0);
        $ret = $self->subvt($symbol, $num, $numoffset) || $ret if ($num > 0);
    } 
    return $ret;
}

sub clean {
    my $self = shift;
    return $self->diff_symbol(@_);
}

sub detect {
    my ($self, $symbol) = @_;
    return $self->diff_symbol($symbol);
}

sub replace {
    my ($self, $substvar, $sym) = @_;
    # vt:$number
    if ($substvar =~ /^{vt:(\d+)}$/) {
        my $number = $1;
        $number *= $self->get_arch_param("mult");
        return "$number";
    } else {
        return undef;
    }
}

1;
