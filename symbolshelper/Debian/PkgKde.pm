package Debian::PkgKde;

use base qw(Exporter);
our @EXPORT = qw(get_program_name
    printmsg info warning errormsg error syserr usageerr);

{
    my $progname;
    sub get_program_name {
	unless (defined $progname) {
	    $progname = ($0 =~ m,/([^/]+)$,) ? $1 : $0;
	}
	return $progname;
    }
}

sub format_message {
    my $type = shift;
    my $format = shift;

    my $msg = sprintf($format, @_);
    return ((defined $type) ?
	get_program_name() . ": $type: " : "") . "$msg\n";
}

sub printmsg {
    print STDERR format_message(undef, @_);
}

sub info {
    print STDERR format_message("info", @_);
}

sub warning {
    warn format_message("warning", @_);
}

sub syserr {
    my $msg = shift;
    die format_message("error", "$msg: $!", @_);
}

sub errormsg {
    print STDERR format_message("error", @_);
}

sub error {
    die format_message("error", @_);
}

sub usageerr {
    die format_message("usage", @_);
}

1;
