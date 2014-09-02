#! /usr/bin/env perl

# Version for KDE4

use strict;
use warnings;
use v5.8.0; # We really want decent Unicode support

use Getopt::Long;

sub printdate
{
    printf ( "%04i", ( $_[5] + 1900 ) );
    print "-";
    printf ( "%02i", $_[4] + 1);
    print "-";
    printf ( "%02i", $_[3] );
    print " ";
    printf ( "%02i", $_[2] );
    print ":";
    printf ( "%02i", $_[1] );
    print "+0000";
}

sub prepare
{
    binmode( STDOUT, ":utf8" );

    my @now = gmtime();
    print "#, fuzzy\n";
    print "msgid \"\"\n";
    print "msgstr \"\"\n";
    print "\"Project-Id-Version: desktop files\\n\"\n";
    print "\"Report-Msgid-Bugs-To: http://bugs.kde.org\\n\"\n";
    print "\"POT-Creation-Date: "; printdate( @now ); print "\\n\"\n";
    print "\"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n\"\n";
    print "\"Last-Translator: FULL NAME <EMAIL\@ADDRESS>\\n\"\n";
    print "\"Language-Team: LANGUAGE <kde-i18n-doc\@kde.org>\\n\"\n";
    print "\"MIME-Version: 1.0\\n\"\n";
    print "\"Content-Type: text/plain; charset=UTF-8\\n\"\n";
    print "\"Content-Transfer-Encoding: 8bit\\n\"\n";
    print "\n\n";
}

sub processfiles
{
    my ( $files, $basedir) = ( @_ );
    for my $filename ( @$files )
    {
        chomp( $filename );
        next if -d $filename;
        open( FH, "<:utf8", $filename ) or warn "Cannot open file $filename";
    
        # print STDERR "Processing $filename...\n"; ### DEBUG
        
        my $regexp = qr{^(Name|Comment|Language|Keywords|X-KDE-Keywords|About|Description|GenericName|Query|ExtraNames|X-KDE-Submenu)=(.+)};

        # Context is given by preceeding the entry with # ctxt:... comment.
        # For example, this:
        #   # ctxt: Blah blah
        #   Name=...
        # ends up as "Name|Blah blah" context in the PO file.
        my $regexp_ctxt = qr{^\s*#\s*ctxt\s*:\s*(.*?)\s*$};
    
        my $context_free = "";
        while( <FH> )
        {
            if ( m/$regexp/o )
            {
                my $context = $1;
                my $msgid = $2;
                if ($context_free) {
                    $context = "$context|$context_free";
                    $context =~ s/\\/\\\\/g;
                    $context =~ s/\"/\\\"/g;
                }
                chomp( $msgid );
                $msgid =~ s/$regexp//;
                $msgid =~ s/\\/\\\\/g;
                $msgid =~ s/\"/\\\"/g;
		if ($msgid =~ m/ +$/) {
                   $msgid =~ s/ +$//; # remove trailing spaces
		   print STDERR "ERROR: white space at the end of $msgid in $filename\n";
		}
                if ($msgid =~ m/\r$/) {
                   $msgid =~ s/[ \r]+$//; # remove trailing space or CR characters
		   print STDERR "ERROR: CR at the end of $msgid in $filename\n";
                }
		$filename =~ s,^$basedir/,,;
                print "#: $filename:$.\n";
                print "msgctxt \"$context\"\n";
                print "msgid \"$msgid\"\n";
                print "msgstr \"\"\n";
                print "\n";
            }
            # Free context refers only to the immediate next line.
            # Thus, if next line is not extracted, current context is gone.
            if ( m/$regexp_ctxt/o ) {
                $context_free = $1;
            } else {
                $context_free = "";
            }
        }
    
        close( FH );
    }
}

my $onefilelist;
my $basedir;
GetOptions ( "file-list=s" => \$onefilelist,
	     "base-dir=s" => \$basedir
	   );

prepare;

open( FILELIST, $onefilelist ) or warn ( "Cannot open file list: $onefilelist" );
my @thislist = <FILELIST>;
processfiles( \@thislist, $basedir );
close( FILELIST );

