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

package Debian::PkgKde::SymbolsHelper::SymbolFile;

use strict;
use warnings;
use base 'Dpkg::Shlibs::SymbolFile';

use File::Temp qw();
use File::Copy qw();
use Storable qw();
use IO::Handle;
use Dpkg::ErrorHandling;
use Dpkg::Version;
use Debian::PkgKde::SymbolsHelper::Symbol;
use Debian::PkgKde::SymbolsHelper::Substs;

# Use Debian::PkgKde::SymbolsHelper::Symbol as base symbol
sub parse {
    my ($self, $fh, $file, $seen, $obj_ref, $base_symbol) = @_;
    unless (defined $base_symbol) {
	$base_symbol = 'Debian::PkgKde::SymbolsHelper::Symbol';
    }
    if (!defined $seen) {
	# Read 'SymbolsHelper-Confirmed' header
	open(my $fh, "<", $file)
	    or error("unable to open symbol file '$file' for reading");
	my $line = <$fh>;
	close $fh;

	chop $line;
	if ($line =~ /^#\s*SymbolsHelper-Confirmed:\s+(.+)$/) {
	    $self->set_confirmed(split(/\s+/, $1));
	}
    }
    return $self->SUPER::parse($fh, $file, $seen, $obj_ref, $base_symbol);
}

sub set_confirmed {
    my ($self, $version, @arches) = @_;
    $self->{h_confirmed_version} = $version;
    $self->{h_confirmed_arches} = (@arches) ? \@arches : undef;
}

sub get_confirmed_version {
    my $self = shift;
    return $self->{h_confirmed_version};
}

sub get_confirmed_arches {
    my $self = shift;
    return (defined $self->{h_confirmed_arches}) ?
	@{$self->{h_confirmed_arches}} : ();
}

sub create_symbol {
    my ($self, $spec, %opts) = @_;
    $opts{base} = Debian::PkgKde::SymbolsHelper::Symbol->new()
	unless exists $opts{base};
    return $self->SUPER::create_symbol($spec, %opts);
}

sub fork_symbol {
    my ($self, $sym, $arch) = @_;
    $arch = $self->get_arch() unless $arch;
    my $nsym = $sym->clone(symbol => $sym->get_symboltempl());
    $nsym->initialize(arch => $arch);
    return $nsym;
}

sub output {
    my ($self, $fh, %opts) = @_;
    $opts{with_confirmed} = 1 unless exists $opts{with_confirmed};
    # Write SymbolsHelper-Confirmed header
    if ($opts{with_confirmed}) {
	my @carches = $self->get_confirmed_arches();
	if (@carches) {
	    print $fh '# SymbolsHelper-Confirmed: ', $self->get_confirmed_version(),
		" ", join(" ", sort @carches), "\n" if defined $fh;
	}
    }
    return $self->SUPER::output($fh, %opts);
}

sub _resync_symbol_cache {
    my ($self, $soname, $cache) = @_;
    my %rename;

    foreach my $symkey (keys %$cache) {
	my $sym = $cache->{$symkey};
	if ($sym->get_symbolname() ne $symkey) {
	    $rename{$sym->get_symbolname()} = $sym;
	    delete $cache->{$symkey};
	}
    }
    foreach my $newname (keys %rename) {
	my $e = $self->get_symbol_object($rename{$newname}, $soname);
	if ($e && ! $rename{$newname}->equals($e)) {
	    warning("caution: newly generated symbol '%s' will replace not exactly equal '%s'. Please readd if unappropriate",
		$rename{$newname}->get_symbolspec(1),
		$e->get_symbolspec(1));
	}
	$self->add_symbol($rename{$newname}, $soname);
    }
}

sub resync_soname_symbol_caches {
    my ($self, $soname) = @_;
    my $obj = $self->get_object($soname);

    # We need this to avoid removal of symbols which names clash when renaming
    $self->_resync_symbol_cache($obj, $obj->{syms});

    # Resync aliases too
    foreach my $alias (values %{$obj->{patterns}{aliases}}) {
	$self->_resync_symbol_cache($obj, $alias);
    }
}

sub resync_soname_with_h_name {
    my ($self, $soname) = @_;
    my $obj = $self->get_object($soname);

    sub _resync_with_h_name {
	my $cache = shift;
	foreach my $symkey (keys %$cache) {
	    $cache->{$symkey}->resync_name_with_h_name();
	}
    }

    # First resync h_name with symbol name and templ
    _resync_with_h_name($obj->{syms});
    foreach my $alias (values %{$obj->{patterns}{aliases}}) {
	_resync_with_h_name($alias);
    }
    return $self->resync_soname_symbol_caches($soname);
}

# Detects (or just neutralizes) substitutes which can be guessed from the
# symbol name alone. Currently unused.
#sub detect_standalone_substs {
#    my ($self, $detect) = @_;
#
#    foreach my $sym ($self->get_symbols()) {
#        my $str = $sym->get_h_name();
#        foreach my $subst (@STANDALONE_SUBSTS) {
#	    if ($detect) {
#	        $subst->detect($str, $self->{arch});
#	    } else {
#	        $subst->neutralize($str);
#	    }
#	}
#    }
#    foreach my $soname (keys %{$self->{objects}}) {
#        # Rename soname object with data in h_name
#	$self->resync_soname_with_h_name($soname);
#    }
#}

# Upgrade virtual table symbols. Needed for templating.
sub prepare_for_templating {
    my $self = shift;
    my %sonames;

    foreach my $soname ($self->get_sonames()) {
	foreach my $sym ($self->get_symbols($soname)) {
	    if ($sym->upgrade_virtual_table_symbol($self->get_arch())) {
		$sonames{$soname} = 1;
	    }
	}
    }

    foreach my $soname (keys %sonames) {
	$self->resync_soname_symbol_caches($soname);
    }
}

sub patch_template {
    my ($self, @patches) = @_;
    my @symfiles;
    my %dumped;

    foreach my $patch (@patches) {
	my $package = $patch->{package} || '';
	my $tmpfile;
	if (!exists $dumped{$package}) {
	    $tmpfile = File::Temp->new(
		TEMPLATE => "${package}_orig.symbolsXXXXXX",
		UNLINK => 0,
	    );
	    $self->output($tmpfile,
		package => $package,
		template_mode => 1,
		with_confirmed => 0,
	    );
	    $tmpfile->close();
	    $dumped{$package} = $tmpfile->filename;
	}
	$tmpfile = File::Temp->new(
	    TEMPLATE => "${package}_patched.symbolsXXXXXX",
	    UNLINK => 1,
	);
	$tmpfile->close();
	unless (File::Copy::copy($dumped{$package}, $tmpfile->filename)) {
	    syserror("unable to copy file '%s' to '%s'",
		$dumped{$package}, $tmpfile->filename);
	}
	if ($patch->apply($tmpfile->filename)) {
	    # Patching was successful. Parse new SymbolFile and return it
	    my $symfile = Debian::PkgKde::SymbolsHelper::SymbolFile->new(
		file => $tmpfile->filename,
		arch => $patch->{arch},
	    );
	    if ($patch->has_info()) {
		$symfile->set_confirmed($patch->{version}, $patch->{arch});
	    } else {
		$symfile->set_confirmed(undef);
	    }
	    push @symfiles, $symfile;
	    last unless wantarray;
	}
    }
    foreach my $file (values %dumped) {
	unless ($File::Temp::KEEP_ALL) {
	    unlink $file;
	}
    }
    return (wantarray) ? @symfiles : $symfiles[0];
}

sub _dclone_exclude {
    my ($target, @exclude) = @_;
    my %saved;
    foreach my $e (@exclude) {
	if (exists $target->{$e}) {
	    $saved{$e} = $target->{$e};
	    delete $target->{$e};
	}
    }
    my $clone = Storable::dclone($target);
    $target->{$_} = $saved{$_} foreach @exclude;
    return $clone;
}

# Forks an empty symbol file (without symbols and patterns) from the current
# one. Other properties are retained.
sub fork_empty {
    my $self = shift;

    my $symfile = _dclone_exclude($self, qw(objects));
    $symfile->clear();
    foreach my $soname ($self->get_sonames()) {
	$symfile->create_object($soname);
	my $obj = $symfile->get_object($soname);
	my $cloned = _dclone_exclude($self->get_object($soname),
	    qw(syms patterns minver_cache));
	$obj->{$_} = $cloned->{$_} foreach keys %$cloned;
    }
    return $symfile;
}

sub fork {
    my ($self, @optinstances) = @_;
    unshift @optinstances, {} unless @optinstances;
    @optinstances = ( $optinstances[0] ) unless wantarray;

    my @symfiles;
    foreach my $opts (@optinstances) {
	my $symfile = $self->fork_empty();
	$symfile->{$_} = $opts->{$_} foreach keys %$opts;
	$symfile->{file} = '';
	push @symfiles, $symfile;
    }

    # Fork symbols
    foreach my $soname ($self->get_sonames()) {
	foreach my $sym ($self->get_symbols($soname),
	                 $self->get_patterns($soname))
	{
	    foreach my $symfile (@symfiles) {
		my $nsym = $self->fork_symbol($sym, $symfile->get_arch());
		$nsym->{h_origin_symbol} = $sym;
		$symfile->add_symbol($nsym, $soname);
	    }
	}
    }
    return (wantarray) ? @symfiles : shift @symfiles;
}


sub get_highest_version {
    my $self = shift;
    my $maxver;

    foreach my $sym ($self->get_symbols(),
                     $self->get_patterns()) {
	if (!$sym->{deprecated} &&
	    (!defined $maxver || version_compare($sym->{minver}, $maxver) > 0))
	{
	    $maxver = $sym->{minver};
	}
    }

    return $maxver;
}

1;
