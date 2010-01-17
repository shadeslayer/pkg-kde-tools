package Debian::PkgKde::SymbolsHelper::String;

use strict;
use warnings;

use overload '""' => \&get_string;

sub new {
    my ($class, $str) = @_;
    return bless { str => $str }, $class;
}

sub substr {
    my ($self, $offset, $length, $repl1, $repl2) = @_;
    if (defined $repl2 || exists $self->{str2}) {
	# If str2 has not been created yet, create it
	if (!exists $self->{str2}) {
	    $self->{str2} = [ split(//, $self->{str}) ];
	}
	# Keep offset information intact with $repl1
	my @repl2;
	if (!defined $repl2) {
	    for (my $i = 0; $i < length($repl1); $i++) {
		if ($i < $length) {
		    push @repl2, $self->{str2}[$offset+$i];
		} else {
		    push @repl2, undef;
		}
	    }
	} else {
	    @repl2 = map { undef } split(//, $repl1);
	    $repl2[0] = $repl2;
	}
	splice @{$self->{str2}}, $offset, $length, @repl2;
    }
    substr($self->{str}, $offset, $length) = $repl1;
}

sub get_string {
    return shift()->{str};
}

sub get_string2 {
    my $self = shift;
    if (defined $self->{str2}) {
	my $str = "";
	foreach my $s (@{$self->{str2}}) {
	    $str .= $s if defined $s;
	}
	return $str;
    }
    return $self->get_string();
}

1;
