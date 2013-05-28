#!/usr/bin/perl -w
use strict;
use CHUNKER::generic;
use CHUNKER::singlefilestats;
use CHUNKER::Borger;
use CHUNKER::metadata;
use CHUNKER::punct;
use CHUNKER::getcorpus;
use CHUNKER::getProjectList;

#/home/varoracc/local/oracc/bld
my $basepath = "/Users/csm22/Work/Cuneiform/git/cuneiform/datain";
my $baseresults = "/Users/csm22/Work/Cuneiform/git/cuneiform/dataout4";

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
#&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/Q002575/Q002575.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P224395/P224395.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P002296/P002296.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P336398/P336398.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P224395/P224395.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P224431/P224431.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P235724/P235724.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P338326/P338326.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P338462/P338462.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P338499/P338499.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P338566/P338566.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P345960/P345960.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P348776/P348776.xtf", $baseresults);
&CHUNKER::singlefilestats::statasinglefile("/Users/csm22/Work/Cuneiform/git/cuneiform/datain/P382687/P382687.xtf", $baseresults);

print "\n\n::";
#&CHUNKER::compilationLang::makeFiles($baseresults."/signs",$baseresults);
&CHUNKER::getProjectList::makeFile($baseresults."/metadata",$baseresults);

print ";;\n\n";
&CHUNKER::generic::writetoerror("timemarking","ending ".localtime);