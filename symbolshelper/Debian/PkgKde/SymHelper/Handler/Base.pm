package Debian::PkgKde::SymHelper::Handler::Base;

use strict;
use warnings;
use Debian::PkgKde::SymHelper qw(error warning);

sub new {
    my ($cls, $arch) = @_;
    my $self = bless {
        arch => undef,
    }, $cls;
    $self->set_arch($arch);
    return $self;
}

sub get_host_arch {
    my $arch = `dpkg-architecture -qDEB_HOST_ARCH_CPU`;
    chomp $arch;
    return $arch;
}

sub set_arch {
    my ($self, $arch) = @_;
    $arch = get_host_arch() unless defined $arch;

    error("Unknown architecture: $arch") unless grep($arch, @Debian::PkgKde::SymHelper::ARCHES);

    my $arch_params;
    $self->{"${arch}_params"} = $arch_params
        if ($arch_params = $self->get_predef_arch_params($arch));
    $self->{arch} = $arch;
}

sub _preload_arch_params {
    my $self = shift;
    foreach my $arch (@_) {
        $self->{"${arch}_params"} = $self->get_predef_arch_params($arch);
    }
}

sub get_arch_param {
    my ($self, $name, $arch) = @_;
    $arch = $self->{arch} unless defined $arch;

    $self->_preload_arch_params($arch) unless (exists $self->{"${arch}_params"});
    return $self->{"${arch}_params"}{$name};
}

sub dump_arch_params {
    my ($self, $arch) = @_;
    $arch = $self->{arch} unless defined $arch;

    if (exists $self->{"${arch}_params"}) {
        print "Arch: $arch", "\n";
        foreach my $key (keys %{$self->{"${arch}_params"}}) {
           print "$key: ", $self->get_arch_param($key, $arch), "\n";
        }
    }
}

sub get_host_arch_params {
    my $self = shift;
    return undef;
}

sub get_predef_arch_params {
    my ($self, $arch) = @_;
    return undef;
}

sub clean {
    my ($self, $sym) = @_;
    return $sym;
}

sub detect {
    my ($self, $symversions) = @_;
    return undef;
}

sub replace {
    my ($self, $substvar, $sym) = @_;
    return undef;
}

1;
