package Debian::PkgKde::SymHelper::SymbFile;
our @ISA = qw( Dpkg::Shlibs::SymbolFile );

use warnings;
use strict;
use Dpkg::Shlibs::SymbolFile;
use Debian::PkgKde::SymHelper qw(error warning);

sub get_symbol_substvars {
    my ($self, $sym) = @_;
    my @substvars;
    while ($sym =~ m/(\{[^}]+\})/g) {
        push @substvars, "$1";
    }
    return @substvars;
}

sub scan_for_substvars {
    my $self = shift;
    my $count = 0;
    delete $self->{subst_objects} if exists $self->{subst_objects};
    while (my($soname, $sonameobj) = each(%{$self->{objects}})) {
        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
            if (my @substvars = $self->get_symbol_substvars($sym)) {
                $self->{subst_objects}{$soname}{syms}{$sym} = \@substvars;
                $count += scalar(@substvars);
            }
        }
    }
    return $count;
}

sub substitute {
    my $self = shift;
    my $handlers = shift;

    return undef unless defined $handlers;

    my $newsymfile = new Debian::PkgKde::SymHelper::SymbFile;

    # Shallow clone our symbol file as a new file object
    while (my ($key, $val) = each(%$self)) {
        $newsymfile->{$key} = $val;
    }

    # We are only interested in {objects}
    $newsymfile->{objects} = {};
    while (my ($soname, $sonameobj) = each(%{$self->{objects}})) {
        if (exists $self->{subst_objects}{$soname}) {
            while (my ($soname_key, $soname_val) = each(%$sonameobj)) {
                $newsymfile->{objects}{$soname}{$soname_key} = $soname_val;
            }
            # Process {syms}
            $newsymfile->{objects}{$soname}{syms} = {};
            while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
                if (exists $self->{subst_objects}{$soname}{syms}{$sym}) {
                    my $substvars = $self->{subst_objects}{$soname}{syms}{$sym};
                    foreach my $substvar (@$substvars) {
                        my ($result, $found);
                        foreach my $handler (@$handlers) {
                            if ($result = $handler->replace($substvar, $sym)) {
                                $info->{oldname} = $sym;
                                $sym =~ s/\Q$substvar\E/$result/g;
                                $found = 1;
                            }
                        }
                        error("Substvar '$substvar' in symbol $sym/$soname was not handled by any substvar handler")
                            unless defined $found;
                    }
                }
                $newsymfile->{objects}{$soname}{syms}{$sym} = $info;
            }
        } else {
            $newsymfile->{objects}{$soname} = $sonameobj;
        }
    }

    return $newsymfile;
}

sub dump_cpp_symbols {
    my ($self, $fh) = @_;

    while (my ($soname, $sonameobj) = each(%{$self->{objects}})) {
        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
                print $fh $sym, "\n" if ($sym =~ /^_Z/);
            }
    }
}

sub load_cppfilt_symbols {
    my ($self, $fh) = @_;

    while (my ($soname, $sonameobj) = each(%{$self->{objects}})) {
        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
            next unless ($sym =~ /^_Z/);
            if (my $cpp = <$fh>) {
                chomp $cpp;
                $info->{cppfilt} = $cpp;
            } else {
                main::error("Unexpected end at c++filt output: '$sym' not demangled");
            }
        }
    }
}

sub deprecate_useless_symbols {
    my $self = shift;
    my $count = 0;
    while (my ($soname, $sonameobj) = each(%{$self->{objects}})) {
        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
            next if ($info->{deprecated});

            if (exists $info->{cppfilt}) {
                # Deprecate template instantiations as they are not
                # useful public symbols
                my $cppfilt = $info->{cppfilt};
                # Prepare for tokenizing: wipe out unnecessary spaces
                $cppfilt =~ s/([,<>()])\s+/$1/g;
                $cppfilt =~ s/\s*((?:(?:un)?signed|volatile|restrict|const|long)[*&]*)\s*/$1/g;
                if (my @tokens = split(/\s+/, $cppfilt)) {
                    my $func;
                    if ($tokens[0] =~ /[(]/) {
                        $func = $tokens[0];
                    } elsif ($#tokens >= 1 && $tokens[1] =~ /[(]/) {
                        # The first token was return type, try the second
                        $func = $tokens[1];
                    }
                    if (defined $func && $func =~ /<[^>]+>[^(]*[(]/) {
                        # print STDERR "Deprecating $sym ", $cppfilt, "\n";
                        # It is template instantiation. Deprecate it
                        $info->{deprecated} = "PRIVATE: TEMPLINST";
                        $count++;
                    }
                }
            }
        }
    }
    return $count;
}

sub dump {
    my $self = shift;
    my ($fh, %opts) = @_;

    if (!exists $opts{with_deprecated} || $opts{with_deprecated} != 2) {
        return $self->SUPER::dump(@_);
    } else {
        foreach my $soname (sort keys %{$self->{objects}}) {
            my @deps = @{$self->{objects}{$soname}{deps}};
            my $dep = shift @deps;
            $dep =~ s/#PACKAGE#/$opts{package}/g if exists $opts{package};
            print $fh "$soname $dep\n";
            foreach $dep (@deps) {
                $dep =~ s/#PACKAGE#/$opts{package}/g if exists $opts{package};
                print $fh "| $dep\n";
            }
            my $f = $self->{objects}{$soname}{fields};
            foreach my $field (sort keys %{$f}) {
                my $value = $f->{$field};
                $value =~ s/#PACKAGE#/$opts{package}/g if exists $opts{package};
                print $fh "* $field: $value\n";
            }
            foreach my $sym (sort keys %{$self->{objects}{$soname}{syms}}) {
                my $info = $self->{objects}{$soname}{syms}{$sym};
                next if $info->{deprecated} and not $opts{with_deprecated};
                ####### START Changes here #########
                print $fh "#", (($info->{deprecated} =~ m/^PRIVATE:/) ? "DEPRECATED" : "MISSING"),
                    ": $info->{deprecated}#" if $info->{deprecated};
                ####### END Changes here #########
                print $fh " $sym $info->{minver}";
                print $fh " $info->{dep_id}" if $info->{dep_id};
                print $fh "\n";
            }
        }
    }
}

sub resync_private_symbols {
    my ($self, $ref) = @_;

    # Remark private symbols in ref as deprecated
    while (my ($soname, $sonameobj) = each(%{$ref->{objects}})) {
        my $mysyms = $self->{objects}{$soname}{syms};
        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
            if (exists $mysyms->{$sym}) {
                if ($info->{deprecated} && $info->{deprecated} =~ m/^PRIVATE/) {
                    $mysyms->{$sym} = $info;
                }
            }
        }
    }
}

sub resync_private_symbol_versions {
    my ($self, $ref, $syncboth) = @_;

    while (my ($soname, $sonameobj) = each(%{$ref->{objects}})) {
        my $mysyms = $self->{objects}{$soname}{syms};
        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
            if (exists $mysyms->{$sym}) {
                if ($info->{deprecated} && $info->{deprecated} =~ m/^PRIVATE/) {
                    my $newinfo;
                    if ($syncboth) {
                        $info->{deprecated} = $mysyms->{$sym}{deprecated};
                        $newinfo = $info;
                    } else {
                        my %newinfo;
                        while (my ($key, $val) = each(%$info)) {
                            $newinfo{$key} = $val;
                        }
                        # Keep deprecation status
                        $newinfo{deprecated} = $mysyms->{$sym}{deprecated};
                        $newinfo = \%newinfo;
                    }
                    $mysyms->{$sym} = $newinfo;
                }
            }
        }
    }
}

sub merge_lost_symbols_to_template {
    my ($self, $origsymfile, $newsymfile) = @_;
    # Note: origsymfile must be = $self->substitute()

    # Process symbols which are missing (lost) in $newsymfile
    for my $n ($newsymfile->get_lost_symbols($origsymfile)) {
        my $soname = $n->{soname};
        my $sym = $n->{name};
        my $origsyms = $origsymfile->{objects}{$soname}{syms};
        my $newsyms = $newsymfile->{objects}{$soname}{syms};

        my $mysym = (exists $origsyms->{$sym}{oldname}) ?
            $origsyms->{$sym}{oldname} : $sym;
        if (exists $newsyms->{$sym}) {
            $self->{objects}{$soname}{syms}{$mysym} = $newsyms->{$sym};
        } else {
            # Mark as missing
            $self->{objects}{$soname}{syms}{$mysym}{deprecated} = "LOST UNKNOWNVER";
        }
    }
}

sub get_new_symbols_as_symbfile {
    my ($self, $ref) = @_;
    my $deps = [ 'dummy dep' ];

    if (my @newsyms = $self->get_new_symbols($ref)) {
        my $newsymfile = new Debian::PkgKde::SymHelper::SymbFile();
        $newsymfile->clear();

        for my $n (@newsyms) {
            my $soname = $n->{soname};
            my $sym = $n->{name};

            $newsymfile->{objects}{$soname}{syms}{$sym} =
                $self->{objects}{$soname}{syms}{$sym};
            $newsymfile->{objects}{$soname}{deps} = $deps;
        }
        return $newsymfile;
    } else {
        return undef;
    }
}

sub merge_symbols_from_symbfile {
    my ($self, $symfile, $warn_about_collisions) = @_;

    while (my ($soname, $sonameobj) = each(%{$symfile->{objects}})) {
        my $mysyms = $self->{objects}{$soname}{syms};
        $mysyms = {} unless (defined $mysyms);

        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
            if (exists $mysyms->{$sym}) {
                warning("$sym exists in both symfiles. Keeping the old one\n")
                    if ($warn_about_collisions)
            } else {
                $mysyms->{$sym} = $info;
            }
        }
        $self->{objects}{$soname}{syms} = $mysyms;
    }
}

sub set_min_version {
    my ($self, $version, %opts) = @_;

    while (my ($soname, $sonameobj) = each(%{$self->{objects}})) {
        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
            $info->{minver} = $version if ($opts{with_deprecated} || !$info->{deprecated});
        }
    }
}

sub fix_min_versions {
    my ($self, %opts) = @_;

    while (my ($soname, $sonameobj) = each(%{$self->{objects}})) {
        while (my ($sym, $info) = each(%{$sonameobj->{syms}})) {
            if ($opts{with_deprecated} || !$info->{deprecated}) {
                my $minver = $info->{minver};
                if ($minver =~ m/-.*[^~]$/) {
                    unless($minver =~ s/-[01](?:$|[^\d-][^-]*$)//) {
                        $minver =~ s/([^~])$/$1~/;
                    }
                    $info->{minver} = $minver;
                }
            }
        }
    }
}

sub handle_min_version {
    my ($self, $version, %opts) = @_;

    if (defined $version) {
        if ($version) {
            $self->set_min_version($version, %opts);
        } else {
            $self->fix_min_versions(%opts);
        }
    }
}

1;
