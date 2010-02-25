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

package Debian::PkgKde::SymbolsHelper::Patching;

use strict;
use warnings;
use base 'Exporter';

use Dpkg::ErrorHandling;

our @EXPORT = qw(parse_patches_from_handle parse_patches_from_file);

sub parse_patches_from_handle {
    my ($fh) = @_;
    my $reparse_line;
    my @patches;
    my $patch;

    while ($reparse_line || ($_ = <$fh>)) {
	$reparse_line = 0;
	if (defined $patch) {
	    if ($patch->has_header()) {
		if (m/^@@ /) {
		    unless ($patch->is_valid()) {
			warning("patch '".$patch->get_name()."' hunk is invalid at line $.");
		    }
		    $patch->append_line($_);
		} elsif (!$patch->is_valid() && m/^[+ -]/) {
		    # Patch continues
		    $patch->append_line($_);
		} else {
		    # Patch ended
		    if ($patch->complete()) {
			push @patches, $patch;
		    } else {
			warning("patch '".$patch->get_name()."' is invalid");
		    }
		    $patch = undef;
		    $reparse_line = 1;
		    next;
		}
	    } elsif (defined $patch->{source}) {
		if (m/^[+]{3}\s+(\S+)/) {
		    # Found the patch header portion
		    $patch->set_target($1);
		} else {
		    $patch = undef;
		    $reparse_line = 1;
		}
	    }
	} elsif (m/^[-]{3}\s+(\S+)(?:\s+\(([^_]+)_([^_]+)_([^_]+)\))?/) {
	    $patch = Debian::PkgKde::SymbolsHelper::Patch->new();
	    $patch->set_source($1);
	    $patch->set_info($2, $3, $4);
	}
    }
    if (defined $patch) {
	if ($patch->complete()) {
	    push @patches, $patch;
	} else {
	    warning("patch '".$patch->get_name()."' is invalid");
	}
    }
    return @patches;
}

sub parse_patches_from_file {
    my ($filename) = @_;
    open(my $fh, "<", $filename) or error("unable to open patch file '$filename'");
    my @ret = parse_patches_from_handle($fh);
    close $fh;
    return @ret;
}

package Debian::PkgKde::SymbolsHelper::Patch;

use strict;
use warnings;

use Dpkg::ErrorHandling;
use Dpkg::IPC;

sub new {
    my $class = shift;
    return bless {
	file => undef,
	source => undef,
	target => undef,
	package => undef,
	version => undef,
	arch => undef,
	patch => undef,
	hunk_minus => 0,
	hunk_plus => 0,
    }, $class;
}

sub set_source {
    my ($self, $srcfile) = @_;
    $self->{source} = $srcfile;
}

sub set_info {
    my ($self, $package, $version, $arch) = @_;
    $self->{package} = $package;
    $self->{version} = $version;
    $self->{arch} = $arch;
}

sub get_info {
    my $self = shift;
    return (
	package => $self->{package},
	version => $self->{version},
	arch => $self->{arch},
    );
}

sub has_info {
    my $self = shift;
    return defined $self->{package};
}

sub set_target {
    my ($self, $target) = @_;
    $self->{target} = $target;
}

sub has_header {
    my $self = shift;
    return defined $self->{source} && defined $self->{target};
}

sub get_name {
    my $self = shift;
    if ($self->{source}) {
	if ($self->has_info()) {
	    return sprintf("%s_%s_%s (--- %s)", $self->{package},
		$self->{version}, $self->{arch}, $self->{source});
	} else {
	    return sprintf("--- %s +++ %s", $self->{source}, $self->{target});
	}
    } else {
	return "<empty patch>";
    }
}

sub is_valid {
    my $self = shift;
    return (defined $self->{hunk_minus} &&
	$self->{hunk_minus} + $self->{hunk_plus} == 0);
}

sub open_patch_fh {
    my ($self, $mode) = @_;
    my $patch = $self->{patch};
    if (!defined $patch) {
	my $var;
	$patch = $self->{patch} = \$var;
    }
    open(my $fh, $mode, $patch)
	or systemerr("unable to open in-memory patch file");
    return $fh;
}

sub append_line {
    my ($self, $line) = @_;
    my $fh = $self->{fh};
    unless (defined $fh) {
	$fh = $self->open_patch_fh(">");
	$self->{fh} = $fh;
    }
    if (defined $self->{hunk_minus}) {
	if ($line =~ /^@@\s*-\d+,(\d+)\s+[+]\d+,(\d+)\s*@@/) {
	    if ($self->{hunk_minus} + $self->{hunk_plus} == 0) {
		$self->{hunk_minus} = $1;
		$self->{hunk_plus} = $2;
	    } else {
		# Bogus patch
		$self->{hunk_minus} = undef;
		$self->{hunk_plus} = undef;
	    }
	} elsif ($line =~ /^-/) {
	    $self->{hunk_minus}--;
	} elsif ($line =~ /^\+/) {
	    $self->{hunk_plus}--;
	} elsif ($line =~ /^ /) {
	    $self->{hunk_minus}--;
	    $self->{hunk_plus}--;
	} else {
	    warning("patch ignored. Invalid patch line: $line");
	    $self->{hunk_minus} = undef;
	    $self->{hunk_plus} = undef;
	}
    }
    print $fh $line;
}

sub complete {
    my $self = shift;
    close $self->{fh};
    delete $self->{fh};
    return $self->is_valid();
}

sub output {
    my ($self, $outfh, $filename) = @_;
    $filename = $self->{target} unless $filename;

    print $outfh "--- ", $filename, "\n";
    print $outfh "+++ ", $filename, "\n";

    my $infh = $self->open_patch_fh("<");
    while (<$infh>) {
	print $outfh $_;
    }
    close $infh;
}

sub apply {
    my ($self, $filename) = @_;

    my $outfile = File::Temp->new(TEMPLATE => "${filename}_patch.out.XXXXXX");
    my $to_patch_process;
    my $pid = spawn(exec => [ "patch", "--posix", "--force", "-r-", "-p0" ],
                            from_pipe => \$to_patch_process,
                            to_handle => $outfile,
                            error_to_handle => $outfile,
                            wait_child => 0
    );
    my $ret = $self->output($to_patch_process, $filename);
    close $to_patch_process;
    wait_child($pid, nocheck => 1);
    $ret &&= !$?;
    if ($ret) {
	$self->{applied} = $filename;
    } else {
	open(my $outputfd, "<", $outfile->filename)
	    or syserr("unable to reopen temporary file");
	my $output;
	while (<$outputfd>) {
	    $output .= $_;
	}
	close $outputfd;
	chop $output;
	$self->{apply_output} = $output;
    }
    return $ret;
}

sub is_applied {
    my $self = shift;
    return $self->{applied};
}

sub get_apply_output {
    my $self = shift;
    return $self->{apply_output};
}
