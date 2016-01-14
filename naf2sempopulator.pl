#!/usr/bin/perl

use strict;
use File::Temp qw/ tempfile tempdir /;
use FindBin qw($Bin);
use XML::LibXML;


# default values
our $eventcorefloc;
our $ksserver;
our $eventcorefloc;
require "$Bin/config.pl";

my $stdinchunk;
{
local $/;
$stdinchunk = <STDIN>;
}


my $parser = XML::LibXML->new();
my $doc= eval {$parser->parse_string($stdinchunk);};

if ($@) {
    print "ERROR: Invalid XML.\n";
    exit();
}


my $xc = XML::LibXML::XPathContext->new( $doc->documentElement()  );

my @nodelist = $xc->findnodes('/NAF/nafHeader/public');
my $urival = "";

if (@nodelist) { $urival = $nodelist[0]->findvalue('./@uri'); }

if ($urival eq "") {
    # create fake <public> , uri
    my $digest = md5_hex($stdinchunk);
    $urival = "http://www.newsreader-project.eu/fakes/$digest.xml";
    my $publicelem = "<public publicId=\"$digest\" uri=\"$urival\"/>";
    my $i = index($stdinchunk, "<nafHeader>") + length "<nafHeader>";
    my $incr=0;
    if (substr($stdinchunk,$i,1) eq "\n") {$incr = 1;}
    substr($stdinchunk, $i+$incr, 0) = $publicelem."\n";
}


my $tmpdir = File::Temp->newdir( DIR => "/tmp", CLEANUP=>1 );
my $filename = $tmpdir."/".((split(/\//,$urival))[-1]);

open IFILE, ">$filename" or die "Cannot create $filename\n";
print IFILE $stdinchunk;
close IFILE;

# process file:

print STDERR "EXEC: cat $filename | java -Xmx2000m -cp $Bin/$eventcorefloc/EventCoreference-1.0-SNAPSHOT-jar-with-dependencies.jar eu.newsreader.eventcoreference.naf.GetSemFromNafStream --project cars --source-frames '$Bin/$eventcorefloc/resources/source.txt' --grammatical-frames '$Bin/$eventcorefloc/resources/grammatical.txt' --contextual-frames '$Bin/$eventcorefloc/resources/contextual.txt' --non-entities --timex-max 5 --perspective --ili $Bin/$eventcorefloc/resources/ili.ttl | java -Xmx2000m -cp $Bin/$eventcorefloc/EventCoreference-1.0-SNAPSHOT-jar-with-dependencies.jar eu.newsreader.eventcoreference.naf.ProcessEventObjectsStream --source-roles 'pb\:A0,pb\:A1' --contextual-match-type 'LEMMA' > '$filename.trig'\n";

system "cat $filename | java -Xmx2000m -cp $Bin/$eventcorefloc/EventCoreference-1.0-SNAPSHOT-jar-with-dependencies.jar eu.newsreader.eventcoreference.naf.GetSemFromNafStream --project cars --source-frames '$Bin/$eventcorefloc/resources/source.txt' --grammatical-frames '$Bin/$eventcorefloc/resources/grammatical.txt' --contextual-frames '$Bin/$eventcorefloc/resources/contextual.txt' --non-entities --timex-max 5 --perspective --ili $Bin/$eventcorefloc/resources/ili.ttl | java -Xmx2000m -cp $Bin/$eventcorefloc/EventCoreference-1.0-SNAPSHOT-jar-with-dependencies.jar eu.newsreader.eventcoreference.naf.ProcessEventObjectsStream --source-roles 'pb\:A0,pb\:A1' --contextual-match-type 'LEMMA' > '$filename.trig'";

print STDERR "EXEC: wget -O /dev/null --post-file '$filename.trig' --header 'Content-type: application/x-trig' $ksserver\n";
my $retcode = system "wget -O /dev/null --post-file '$filename.trig' --header 'Content-type: application/x-trig' $ksserver";

if ( $retcode != 0 ) 
{ 
        print STDERR "ERROR: Something went wrong while inserting trig into the KS."; 
}

# print input NAF file for the next component

print $stdinchunk;
