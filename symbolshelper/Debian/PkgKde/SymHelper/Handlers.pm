package Debian::PkgKde::SymHelper::Handlers;

use strict;
use warnings;
use File::Temp qw(tempfile);
use Debian::PkgKde::SymHelper::Handler::VirtTable;
use Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff;
use Debian::PkgKde::SymHelper::Symbol;
use Debian::PkgKde::SymHelper::Symbol2;
use Debian::PkgKde::SymHelper qw(info error warning);

sub new {
    my $cls = shift;
    my @standalone_substitution = (
        new Debian::PkgKde::SymHelper::Handler::VirtTable,
    );
    my @multiple_substitution = (
        new Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::size_t,
        new Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::ssize_t,
        new Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::int64_t,
        new Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::uint64_t,
        new Debian::PkgKde::SymHelper::Handler::SimpleTypeDiff::qreal,
    );
    my @substitution = (
        @standalone_substitution,
        @multiple_substitution,
    );
    return bless { subst => \@substitution,
                   multiple_subst => \@multiple_substitution,
                   standalone_subst => \@standalone_substitution }, $cls;
}

sub load_symbol_files {
    my $self = shift;
    my $files = shift;

    return 0 if (exists $self->{symfiles});

    while (my ($arch, $file) = each(%$files)) {
        $self->add_symbol_file(new Debian::PkgKde::SymHelper::SymbFile($file), $arch);
    }

    # Set main architecture
    $self->set_main_arch();

    return scalar(keys %{$self->{symfiles}});
}

sub add_symbol_file {
    my ($self, $symfile, $arch) = @_;
    $arch = Debian::PkgKde::SymHelper::Handler::get_host_arch() unless (defined $arch);

    $self->{symfiles}{$arch} = $symfile;
    $self->{main_arch} = $arch unless ($self->{main_arch});
}

sub get_main_arch {
    my $self = shift;
    return (exists $self->{main_arch}) ? $self->{main_arch} : undef;
}

sub set_main_arch {
    my ($self, $arch) = @_;
    $arch = Debian::PkgKde::SymHelper::Handler::get_host_arch() unless defined $arch;
    $self->{main_arch} = $arch if ($self->get_symfile($arch));
}

sub get_symfile {
    my ($self, $arch) = @_;
    if (exists $self->{symfiles}) {
        $arch = $self->get_main_arch() unless defined $arch;
        return (exists $self->{symfiles}{$arch}) ? $self->{symfiles}{$arch} : undef;
    } else {
        return undef;
    }
}

sub cppfilt {
    my $self = shift;
    my @symfiles;

    if (!@_) {
        return 0 if (!exists $self->{symfiles} || exists $self->{cppfilt});
        push @symfiles, values %{$self->{symfiles}};
    } else {
        push @symfiles, @_;
    }

    # Open temporary file
    my ($fh, $filename) = File::Temp::tempfile();
    if (defined $fh) {
        # Dump cpp symbols to the temporary file
        foreach my $symfile (@symfiles) {
            $symfile->dump_cpp_symbols($fh);
        }
        close($fh);

        # c++filt the symbols and load them
        open(CPPFILT, "cat '$filename' | c++filt |") or main::error("Unable to run c++filt");
        foreach my $symfile (@symfiles) {
            $symfile->load_cppfilt_symbols(*CPPFILT);
        }
        close(CPPFILT);

        # Remove temporary file
        unlink($filename);

        $self->{cppfilt} = 1 if (!@_);

        return 1;
    } else {
        main::error("Unable to create a temporary file");
    }
}

sub preprocess {
    my $self = shift;
    my $count = 0;

    if (!@_) {
        return 0 unless (exists $self->{symfiles});
        $self->cppfilt();
        push @_, values(%{$self->{symfiles}});
    } else {
        $self->cppfilt(@_);
    }
    foreach my $symfile (@_) {
        $count += $symfile->deprecate_useless_symbols();
    }
    return $count;
}

sub get_group_name {
    my ($self, $symbol, $arch) = @_;

    my $osym = new Debian::PkgKde::SymHelper::Symbol($symbol, $arch);
    foreach my $handler (@{$self->{subst}}) {
        $handler->clean($osym);
    }
    return $osym->get_symbol();
}

sub _process_standalone {
    my $self = shift;
    my $create = shift; # 0 - clean symbols, 1 - create template

    return undef unless (exists $self->{symfiles});

    my $symfiles = $self->{symfiles};

    while (my ($arch, $symfile) = each %$symfiles) {
        while (my ($soname, $sonameobj) = each(%{$symfile->{objects}})) {
            my @syms = keys(%{$sonameobj->{syms}});
            my %rename; # We need this hash to avoid name clashing
            for my $sym (@syms) {
                my $symbol = new Debian::PkgKde::SymHelper::Symbol($sym, $arch);
                my $symbol2 = new Debian::PkgKde::SymHelper::Symbol2($sym, $arch);
                my $handled;
                foreach my $handler (@{$self->{standalone_subst}}) {
                    if ($handler->detect($symbol2)) {
                        $handled = 1;
                        # Make symbol arch independent with regard to this handler
                        $handler->clean($symbol);
                    }
                }

                my $newsym = ($create) ? $symbol2->get_symbol2() : $symbol->get_symbol();
                my $info = $sonameobj->{syms}{$sym};
                if ($sym ne $newsym) {
                    $rename{$newsym} = $info;
                    delete $sonameobj->{syms}{$sym};
                }
                # Preserve symbol2 if clean requested
                if (!$create && $handled) {
                    $info->{__symbol2__} = $symbol2;
                }
            }
            # We need this to avoid removal of symbols which names clash when renaming
            while (my($newname, $info) = each %rename) {
                $sonameobj->{syms}{$newname} = $info;
            }
        }
    }
    return $self->get_symfile();
}

sub create_template_standalone {
    my $self = shift;
    return $self->_process_standalone(1);
}

sub create_template {
    my $self = shift;
    my %opts = @_;

    # opts:
    #   deprecate_incomplete - add symbols from incomplete groups
    #                          as deprecated.

    return undef unless (exists $self->{symfiles});

    my $symfiles = $self->{symfiles};
    my $main_arch = $self->get_main_arch();

    # Process with standalone handlers first. Get a symfile with __symbol2__
    my $symbol2symfile = $self->_process_standalone();

    # Collect new symbols from them by grouping them using the
    # fully arch independent derivative name
    my %symbols;
    foreach my $arch1 (@Debian::PkgKde::SymHelper::ARCHES) {
        next unless exists $symfiles->{$arch1};

        foreach my $arch2 (@Debian::PkgKde::SymHelper::ARCHES) {
            next if $arch1 eq $arch2;
            next unless exists $symfiles->{$arch2};

            my @new = $symfiles->{$arch1}->get_new_symbols($symfiles->{$arch2});
            foreach my $n (@new) {
                my $g = $self->get_group_name($n->{name}, $arch1);
                my $s = $n->{soname};
                if (exists $symbols{$s}{$g}{arches}{$arch1}) {
                    if ($symbols{$s}{$g}{arches}{$arch1}->get_symbol() ne $n->{name}) {
                        warning("at least two new symbols get to the same group ($g) on $s/$arch1:\n" .
                            "  " . $symbols{$s}{$g}{arches}{$arch1}->get_symbol() . "\n" .
                            "  " . $n->{name});
                        # Ban group
                        $symbols{$s}{$g}{banned} = "ambiguous";
                    }
                } else {
                    $symbols{$s}{$g}{arches}{$arch1} = new Debian::PkgKde::SymHelper::Symbol($n->{name}, $arch1);
                }
            }
        }
    }

    # Do substvar detection
    my $arch_count = scalar(keys(%$symfiles));

    # Missing archs check
    my %arch_ok;
    my $arch_ok_i = 0;
    while (my($arch, $f) = each(%$symfiles)) {
        $arch_ok{$arch} = $arch_ok_i;
    }

    my %other_groups;
    while (my ($soname, $groups) = each(%symbols)) {
        $other_groups{$soname} = [];
        while (my ($name, $group) = each(%$groups)) {
            # Check if the group is not banned 
            next if exists $group->{banned};

            # Check if the group is complete
            my $count = scalar(keys(%{$group->{arches}}));
            my $sym_arch = $main_arch;
            if ($count < $arch_count) {
                $group->{banned} = "incomplete";
                # Additional vtables are usual on armel
                next if ($count == 1 && exists $group->{arches}{armel} && $group->{arches}{armel}->is_vtt());

                $arch_ok_i++;
                warning("ignoring incomplete group '$name/$soname' ($count < $arch_count). Symbol dump below:");
                foreach my $arch (sort(keys %{$group->{arches}})) {
                    info("  " . $group->{arches}{$arch}->get_symbol() . "/" . $arch . "\n");
                    $arch_ok{$arch} = $arch_ok_i;
                }
                info("  - missing on:");
                for my $arch (sort(keys %arch_ok)) {
                    info(" $arch") if (defined $arch_ok{$arch} && $arch_ok{$arch} != $arch_ok_i);
                }
                info("\n");

                if (defined $opts{deprecate_incomplete}) {
                    info("  - including this symbol in the template anyway\n");
                    delete $group->{banned};
                    $group->{deprecate} = "PRIVATE: ARCH: " . join(" ", sort(keys %{$group->{arches}}));
                    # Determine symbol arch, prefer main_arch though
                    if (!exists $group->{arches}{$main_arch}) {
                        $sym_arch = (keys %{$group->{arches}})[0];
                    }
                } else {
                    next;
                }
            }

            # Main symbol
            my $symname = $group->{arches}{$sym_arch}->get_symbol();
            my $main_symbol;
            if (exists $symbol2symfile->{objects}{$soname}{syms}{$symname}{__symbol2__}) {
                $main_symbol = $symbol2symfile->{objects}{$soname}{syms}{$symname}{__symbol2__};
            } else {
                $main_symbol = new Debian::PkgKde::SymHelper::Symbol2($symname, $sym_arch);
            }
            foreach my $handler (@{$self->{multiple_subst}}) {
                if ($handler->detect($main_symbol, $group->{arches})) {
                    # Make archsymbols arch independent with regard to his handler
                    while (my ($arch, $symbol) = each(%{$group->{arches}})) {
                        $handler->clean($symbol);
                    }
                }
            }
            $group->{template} = $main_symbol;
            if ($main_arch ne $sym_arch) {
                push @{$other_groups{$soname}}, $group;
            }
        }
    }

    # Finally, integrate our template into $main_arch symfile
    my $main_symfile = $symfiles->{$main_arch};
    while (my ($soname, $sonameobj) = each(%{$main_symfile->{objects}})) {
        my @syms = keys(%{$sonameobj->{syms}});
        for my $sym (@syms) {
            my $g = $self->get_group_name($sym, $main_arch);
            my $symbol2;
            my $deprecate;
            if (exists $symbols{$soname}{$g}) {
                my $group = $symbols{$soname}{$g};
                if (!exists $group->{banned}) {
                    $symbol2 = $group->{template};
                } elsif (exists $group->{deprecate}) {
                    $symbol2 = $group->{template};
                    $deprecate = $group->{deprecate};
                }
            } elsif (exists $sonameobj->{syms}{$sym}{__symbol2__}) {
                $symbol2 = $sonameobj->{syms}{$sym}{__symbol2__};
            } else {
                next; # Leave this symbol alone
            }
            if (defined $symbol2) {
                # Rename symbol
                my $info = $sonameobj->{syms}{$sym};
                if (defined $deprecate) {
                    $info->{deprecated} = $deprecate;
                }
                delete $sonameobj->{syms}{$sym};
                $sonameobj->{syms}{$symbol2->get_symbol2()} = $info;
            } elsif (exists $sonameobj->{syms}{$sym}) {
                delete $sonameobj->{syms}{$sym}
                    unless ($sonameobj->{syms}{$sym}{deprecated});
            }
        }
    }

    # Add symbols from "other groups" (they are new in main_symfile)
    while (my ($soname, $groups) = each(%other_groups)) {
        for my $group (@$groups) {
            my $symbol2 = $group->{template};

            if (defined $symbol2) {
                # Add symbol
                my $info = $symfiles->{$symbol2->get_arch()}{objects}{$soname}{syms}{$symbol2->get_symbol()};
                if ($group->{deprecate}) {
                    $info->{deprecated} = $group->{deprecate};
                }
                $main_symfile->{objects}{$soname}{syms}{$symbol2->get_symbol2()} = $info;
            } 
        }
    }

    return $main_symfile;
}

sub substitute {
    my ($self, $file, $arch) = @_;
    my $symfile = new Debian::PkgKde::SymHelper::SymbFile($file);

    foreach my $h (@{$self->{subst}}) {
        $h->set_arch($arch);
    }
    if ($symfile->scan_for_substvars()) {
        return $symfile->substitute($self->{subst});
    } else {
        return undef;
    }
}

sub apply_patch_to_template {
    my ($self, $patchfh, $infile, $arch, $newminver) = @_;

    # Dump arch specific symbol file to temporary location
    my $archsymfile = $self->substitute($infile, $arch);
    my ($archfh, $archfn) = File::Temp::tempfile();
    $archsymfile->dump($archfh);
    close($archfh);

    # Adopt the patch to our needs (filename)
    my $file2patch;
    my $is_patch;
    my $sameline = 0;
    while($sameline || ($_ = <$patchfh>)) {
        $sameline = 0;
        if (defined $is_patch) {
            if (m/^(?:[+ -]|@@ )/) {
                # Patch continues
                print PATCH $_;
                $is_patch++;
            } else {
                # Patch ended
                if (!close(PATCH)) {
                    # Continue searching for another patch
                    $sameline = 1;
                    $file2patch = undef;
                    $is_patch = undef;
                    next;
                } else {
                    $file2patch = undef;
                    # $is_patch stays set
                    last;
                }
            }
        } elsif (defined $file2patch) {
            if (m/^[+]{3}\s+\S+/) {
                # Found the patch portion. Write the patch header
                $is_patch = 0;
                open(PATCH, "| patch -p0 >/dev/null 2>&1") or die "Unable to execute `patch` program";
                print PATCH "--- ", $archfn, "\n";
                print PATCH "+++ ", $archfn, "\n";
            } else {
                $file2patch = undef;
            }
        } elsif (m/^[-]{3}\s+(\S+)/) {
            $file2patch = $1;
        }
    }
    if(($file2patch && close(PATCH)) || $is_patch) {
        # Patching was successful. Reparse
        my $insymfile = new Debian::PkgKde::SymHelper::SymbFile($infile);
        my $newsymfile = new Debian::PkgKde::SymHelper::SymbFile($archfn);

        # Resync private symbols in newsymfile with archsymfile
        $newsymfile->resync_private_symbols($archsymfile);

        # Merge lost symbols
        if ($insymfile->merge_lost_symbols_to_template($archsymfile, $newsymfile)) {
            # Dump new MISSING symbols
            my $dummysymfile = new Debian::PkgKde::SymHelper::SymbFile();
            $dummysymfile->merge_lost_symbols_to_template($archsymfile, $newsymfile);

            info("-- Added new MISSING symbols --\n");
            while (my ($soname, $obj) = each %{$dummysymfile->{objects}}) {
                $obj->{deps} = [ 'dummy dep' ];
            }
            $dummysymfile->dump(*STDOUT, with_deprecated => 1);
        }

        # Now process new symbols. We need to create a template from them
        if (my $dummysymfile = $newsymfile->get_new_symbols_as_symbfile($archsymfile)) {
            $self->add_symbol_file($dummysymfile, $arch);
            $self->preprocess();

            # Handle min version
            $dummysymfile->handle_min_version($newminver, with_deprecated => 1);

            # Dump new symbols
            info("-- Added new symbols --\n");
            $dummysymfile->dump(*STDOUT, with_deprecated => 2);

            # Create a symbols template for our dummy file
            $dummysymfile = $self->create_template_standalone();

            # Finally, merge it to our $insymfile
            $insymfile->merge_symbols_from_symbfile($dummysymfile, 1);
        }
        unlink($archfn);
        return return $insymfile;
    } else {
        # Patching failed
        unlink($archfn);
        return undef;
    }
}

1;
