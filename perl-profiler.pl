#!/usr/bin/perl -w

# Based on /usr/share/doc/libdevel-nytprof-perl/examples/demo/demo-run.pl
# from the libdevel-nytprof-perl package.
# License: Artistic or GPL-1+

use strict;
use IO::Handle;

my $NYTPROF = ($ENV{NYTPROF}) ? "$ENV{NYTPROF}:" : "";

my %runs = (
    start_begin => {
        skip => 0,
        NYTPROF => 'start=begin:optimize=0',
    },
    start_check => {
        skip => 1,
        NYTPROF => 'start=init:optimize=0',
    },
    start_end => {
        skip => 1,
        NYTPROF => 'start=end:optimize=0',
    },
);

my $bin = shift @ARGV;
my $name = $bin;
$name =~ s,^.*/,,;

for my $run (keys %runs) {

    next if $runs{$run}{skip};
    $ENV{NYTPROF}      = $NYTPROF . $runs{$run}{NYTPROF} || '';
    $ENV{NYTPROF_HTML} = $runs{$run}{NYTPROF_HTML} || '';

    my $cmd = "perl -d:NYTProf $bin @ARGV";
    open my $fh, "| $cmd"
        or die "Error starting $cmd\n";
    $fh->autoflush;
    close $fh
        or die "Error closing pipe to $cmd: $!\n";

    my $outdir = "${name}-profiler/$run";
    system("rm -rf $outdir") == 0 or exit 0;
    system("mkdir -p $outdir") == 0 or exit 0;
    system("nytprofhtml --open --out=$outdir") == 0
        or exit 0;

    #system "ls -lrt $outdir/.";

    sleep 1;
}

