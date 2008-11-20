package Debian::PkgKde::SymHelper;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(error warning info);
use File::Basename qw(basename);

our @ARCHES = (
    'i386', 'kfreebsd-i386', 'hurd-i386',
    'amd64', 'kfreebsd-amd64',
    'alpha',
    'arm',
    'armel',
    'hppa',
    'ia64',
    'mips',
    'mipsel',
    'powerpc',
    's390',
    'sparc',
    'm68k',
);

sub get_program_name {
    return basename($0);
}

sub error {
    my $msg = shift;
    print STDERR "(", get_program_name(), ") error: ", $msg, "\n";
    exit 1;
}

sub warning {
    my $msg = shift;
    print STDERR "(", get_program_name(), ") warning: ", $msg, "\n";
}

sub info {
    my $msg = shift;
    print STDERR $msg;
}
