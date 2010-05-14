use Test::More;
use File::Find;

my @files;

# Find all perl modules
find(sub { push @files, $File::Find::name if /\.pm$/ }, "perllib", "datalib");

# Find all perl executables in the top level
foreach my $file (glob('*')) {
    if (-f $file && -x $file) {
        open(my $fh, "<", $file) or die "Unable to open $file for reading";
        my $line = <$fh>;
        if ($line =~ /^#!.*\/perl$/) {
            push @files, $file;
        }
        close($fh);
    }
}

# Setup a plan
plan tests => scalar(@files);

foreach my $file (@files) {
    isnt(system("LANG=C $^X -c $file 2>&1 | grep -v 'syntax OK\$' >&2"), 0,
        "Syntax check of $file");
}
