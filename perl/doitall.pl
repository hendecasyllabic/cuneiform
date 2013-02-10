#!/usr/bin/perl -w
use strict;
use CHUNKER::generic;
use CHUNKER::singlefilestats;
use CHUNKER::Borger;
use CHUNKER::metadata;
use CHUNKER::punct;
use CHUNKER::getcorpus;

#/home/varoracc/local/oracc/bld
my $basepath = "/Users/csm22/Documents/workspace/cuneiform/datain";
my $baseresults = "/Users/csm22/Documents/workspace/cuneiform/dataout4";

use CGI qw(:all *table *Tr *td);
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;

&CHUNKER::generic::writetoerror("timemarking","starting ".localtime);
# first get a list of all the texts and some basic meta data
#&CHUNKER::getcorpus::getthetexts($baseresults, $basepath);

#initialise Borger and osl

my $ogslfile = "../resources/ogsl.xml";
my $Borgerfile = "../resources/Borger.xml";
&CHUNKER::Borger::openOgslAndBorger($ogslfile, $Borgerfile);


#second loop over those texts and do the stats stuff
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Documents/workspace/cuneiform/datain/dcclt/P348/P348657/P348657.xtf", $baseresults);


&CHUNKER::generic::writetoerror("timemarking","ending ".localtime);